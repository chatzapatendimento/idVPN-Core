#!/bin/bash
#
# SCRIPT: generate_client.sh
# DESCRIÇÃO: Gera um novo perfil de cliente OpenVPN (.ovpn) usando Easy-RSA diretamente.
# USO: sudo ./generate_client.sh <nome_do_cliente> [id_serial] [display_name]
#
# DATA: 2025-07-10
# ATUALIZADO POR: Gemini CLI (Reescrita Completa)

# --- Validação de Segurança ---
if [ "$EUID" -ne 0 ]; then
  echo "ERRO: Este script precisa ser executado como root (ou com sudo)." >&2
  exit 1
fi

if [ -z "$1" ]; then
  echo "USO: sudo $0 <nome_do_cliente> [id_serial] [display_name]" >&2
  echo "Exemplo: sudo $0 cliente_empresa_x 0M0210/0042A7 \"Escritório Principal\"" >&2
  exit 1
fi

# --- Variáveis ---
CLIENT_NAME="$1"
ID_SERIAL="${2:-}" # Opcional, padrão vazio
DISPLAY_NAME="${3:-}" # Opcional, padrão vazio

# Validação para permitir apenas caracteres seguros no nome do cliente.
if ! [[ "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "ERRO: Nome de cliente inválido. Use apenas letras, números, '-' e '_'." >&2
  exit 1
fi

# Caminhos e configurações
EASYRSA_DIR="/etc/openvpn/easy-rsa"
CA_CRT_PATH="${EASYRSA_DIR}/pki/ca.crt"
TA_KEY_PATH="/etc/openvpn/easy-rsa/pki/ta.key"
CCD_DIR="/etc/openvpn/ccd"
PROFILES_DIR="/home/pi/idVPN-Core/profiles"
METADATA_FILE="${PROFILES_DIR}/metadata.json"
WEB_USER="pi" # Usuário que executa o painel web (para permissões)
CERT_EXPIRE_DAYS="1080" # Dias de expiração do certificado

# Configurações da VPN (do setupVars.conf)
VPN_SUBNET="10.10.206.0"
SUBNET_CLASS="24"

# Conteúdo do template OVPN padrão (reconstruído de um perfil existente)
DEFAULT_OVPN_TEMPLATE_CONTENT="client
dev tun
proto udp
remote pivpnaraponto.ddns.net 1194
resolv-retry infinite
nobind
remote-cert-tls server
tls-version-min 1.2
verify-x509-name pivpn_1824e6c9-5ae6-4454-8f76-24dda26eb99d name
cipher AES-256-CBC
auth SHA256
auth-nocache
verb 3"

# --- Funções Auxiliares (de ipaddr_utils.sh) ---
decIPv4ToDot() {
  local a b c d
  a=$((($1 & 4278190080) >> 24))
  b=$((($1 & 16711680) >> 16))
  c=$((($1 & 65280) >> 8))
  d=$(($1 & 255))
  printf "%s.%s.%s.%s\\n" $a $b $c $d
}

dotIPv4ToDec() {
  local original_ifs=$IFS
  IFS='.'
  read -r -a array_ip <<< "$1"
  IFS=$original_ifs
  printf "%s\\n" $((array_ip[0] * 16777216 + array_ip[1] * 65536 + array_ip[2] * 256 + array_ip[3]))
}

dotIPv4FirstDec() {
  local decimal_ip decimal_mask
  decimal_ip=$(dotIPv4ToDec "$1")
  decimal_mask=$((2 ** 32 - 1 ^ (2 ** (32 - $2) - 1)))
  printf "%s\\n" "$((decimal_ip & decimal_mask))"
}

dotIPv4LastDec() {
  local decimal_ip decimal_mask_inv
  decimal_ip=$(dotIPv4ToDec "$1")
  decimal_mask_inv=$((2 ** (32 - $2) - 1))
  printf "%s\n" "$((decimal_ip | decimal_mask_inv))"
}

cidrToMask() {
  set -- $((5 - (${1} / 8))) \
    255 255 255 255 \
    $(((255 << (8 - (${1} % 8))) & 255)) \
    0 0 0
  shift "${1}"
  echo "${1-0}.${2-0}.${3-0}.${4-0}"
}

# --- Lógica Principal ---
echo "INFO: Iniciando a geração do perfil para o cliente: ${CLIENT_NAME}..."

# 1. Gerar Certificado e Chave do Cliente com Easy-RSA
cd "${EASYRSA_DIR}" || { echo "ERRO: Diretório Easy-RSA não encontrado." >&2; exit 1; }

export EASYRSA_CERT_EXPIRE="${CERT_EXPIRE_DAYS}"
./easyrsa build-client-full "${CLIENT_NAME}" nopass || { echo "ERRO: Falha ao gerar certificado/chave com Easy-RSA." >&2; exit 1; }

echo "INFO: Certificado e chave gerados para ${CLIENT_NAME}."

# 2. Encontrar um IP disponível e criar entrada CCD
FIRST_IPV4_DEC=$(dotIPv4FirstDec "${VPN_SUBNET}" "${SUBNET_CLASS}")
LAST_IPV4_DEC=$(dotIPv4LastDec "${VPN_SUBNET}" "${SUBNET_CLASS}")
SUBNET_MASK=$(cidrToMask "${SUBNET_CLASS}")
UNUSED_IPV4_DOT=""

for ((ip = FIRST_IPV4_DEC + 2; ip <= LAST_IPV4_DEC - 1; ip++)); do
  CURRENT_IP_DOT=$(decIPv4ToDot "${ip}")
  # Verifica se o IP já está em uso em algum arquivo CCD
  if ! grep -q "${CURRENT_IP_DOT}" "${CCD_DIR}"/* 2>/dev/null; then
    UNUSED_IPV4_DOT="${CURRENT_IP_DOT}"
    break
  fi
done

if [ -z "${UNUSED_IPV4_DOT}" ]; then
  echo "ERRO: Não foi possível encontrar um IP disponível na rede VPN." >&2
  exit 1
fi

echo "INFO: IP disponível encontrado: ${UNUSED_IPV4_DOT}"

# Criar arquivo CCD
echo "ifconfig-push ${UNUSED_IPV4_DOT} ${SUBNET_MASK}" > "${CCD_DIR}/${CLIENT_NAME}" || { echo "ERRO: Falha ao criar arquivo CCD." >&2; exit 1; }
chown root:openvpn "${CCD_DIR}/${CLIENT_NAME}"
chmod 640 "${CCD_DIR}/${CLIENT_NAME}"
echo "INFO: Arquivo CCD criado em ${CCD_DIR}/${CLIENT_NAME}."

# 3. Construir o arquivo .ovpn
CLIENT_OVPN_PATH="${PROFILES_DIR}/${CLIENT_NAME}.ovpn"
CLIENT_CRT_PATH="${EASYRSA_DIR}/pki/issued/${CLIENT_NAME}.crt"
CLIENT_KEY_PATH="${EASYRSA_DIR}/pki/private/${CLIENT_NAME}.key"

{
  echo "${DEFAULT_OVPN_TEMPLATE_CONTENT}"

  echo "<ca>"
  cat "${CA_CRT_PATH}"
  echo "</ca>"

  echo "<cert>"
  cat "${CLIENT_CRT_PATH}"
  echo "</cert>"

  echo "<key>"
  cat "${CLIENT_KEY_PATH}"
  echo "</key>"

  echo "<tls-crypt>"
  cat "${TA_KEY_PATH}"
  echo "</tls-crypt>"
} > "${CLIENT_OVPN_PATH}" || { echo "ERRO: Falha ao construir o arquivo OVPN." >&2; exit 1; }

# 4. Ajustar permissões do arquivo OVPN
chown "${WEB_USER}:${WEB_USER}" "${CLIENT_OVPN_PATH}" || { echo "ERRO: Falha ao ajustar permissões do OVPN." >&2; exit 1; }
chmod 640 "${CLIENT_OVPN_PATH}"
echo "INFO: Perfil OVPN criado em ${CLIENT_OVPN_PATH} com permissões ajustadas."

# 5. Salvar metadados (ID/Serial e Nome Personalizado)
if [ ! -f "${METADATA_FILE}" ]; then
  echo "{}" > "${METADATA_FILE}"
  chown "${WEB_USER}:${WEB_USER}" "${METADATA_FILE}"
fi

# Usar jq para atualizar o JSON. Se jq não estiver instalado, isso falhará.
# É uma dependência que deve ser garantida na instalação do PiVPN ou adicionada.
if command -v jq &> /dev/null; then
  TEMP_JSON=$(mktemp)
  jq --arg name "$CLIENT_NAME" \
     --arg serial "$ID_SERIAL" \
     --arg display "$DISPLAY_NAME" \
     '.[$name] = { "serial": $serial, "display_name": $display }' \
     "${METADATA_FILE}" > "$TEMP_JSON" && cp "$TEMP_JSON" "${METADATA_FILE}" && rm "$TEMP_JSON"
  chown "${WEB_USER}:${WEB_USER}" "${METADATA_FILE}"
  chmod 660 "${METADATA_FILE}"
  echo "INFO: Metadados salvos em ${METADATA_FILE}."
else
  echo "AVISO: 'jq' não encontrado. Metadados não foram salvos no JSON." >&2
fi

echo "INFO: Processo de geração concluído para ${CLIENT_NAME}."

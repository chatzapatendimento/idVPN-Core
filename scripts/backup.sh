#!/bin/bash
#
# SCRIPT: backup.sh
# DESCRIÇÃO: Realiza o backup compactado das configs e perfis, e envia para o GitHub Releases.
# USO: sudo ./backup.sh
#
# DATA: 2025-07-14
# ATUALIZADO POR: Gemini CLI

# --- Validação de Segurança ---
if [ "$EUID" -ne 0 ]; then
  echo "ERRO: Este script precisa ser executado como root (ou com sudo) para acessar todos os arquivos." >&2
  exit 1
fi

# --- Variáveis ---
# Diretórios e arquivos para fazer backup
SOURCE_DIRS="/etc/openvpn /home/pi/idVPN-Core/profiles" 

# Diretório de destino para os backups temporários
BACKUP_DIR="/home/pi/idVPN-Core/backups"
# Formato do nome do arquivo de backup com data e hora
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILENAME="idvpn-backup-${TIMESTAMP}.tar.gz"
BACKUP_FILE_PATH="${BACKUP_DIR}/${BACKUP_FILENAME}"

# --- Variáveis do GitHub ---
# ATENÇÃO: O usuário que executa o script (ou o root) deve estar autenticado com 'gh auth login'
REPO="chatzapatendimento/idVPN-Core"
RELEASE_TAG="backup-${TIMESTAMP}"

# --- Lógica Principal ---
echo "INFO: Iniciando o processo de backup..."

# Verifica se o diretório de backup existe, senão o cria.
if [ ! -d "$BACKUP_DIR" ]; then
  echo "INFO: Diretório de backup não encontrado. Criando em ${BACKUP_DIR}..."
  mkdir -p "$BACKUP_DIR"
  chown pi:pi "$BACKUP_DIR"
fi

# Cria o arquivo de backup compactado
echo "INFO: Criando o arquivo de backup local: ${BACKUP_FILENAME}..."
if ! tar -czf "${BACKUP_FILE_PATH}" ${SOURCE_DIRS}; then
  echo "ERRO: Falha ao criar o arquivo de backup local." >&2
  exit 1
fi
echo "SUCESSO: Backup local criado em ${BACKUP_FILE_PATH}"

# Envia o backup para o GitHub Releases
echo "INFO: Enviando o backup para o GitHub Releases do repositório ${REPO}..."
if ! sudo -u pi gh release create "${RELEASE_TAG}" "${BACKUP_FILE_PATH}" --repo "${REPO}" --title "Backup Automático ${TIMESTAMP}" --notes "Backup automático dos perfis de cliente e configurações do OpenVPN gerado em ${TIMESTAMP}."; then
  echo "ERRO: Falha ao enviar o backup para o GitHub Releases." >&2
  # Não remove o backup local se o upload falhar, para segurança
  exit 1
fi
echo "SUCESSO: Backup enviado para o GitHub Releases com a tag ${RELEASE_TAG}."

# Remove o backup local após o upload bem-sucedido
echo "INFO: Removendo o arquivo de backup local para economizar espaço..."
rm "${BACKUP_FILE_PATH}"
echo "SUCESSO: Arquivo local removido."

# --- Lógica de Retenção (Agora no GitHub) ---
# A retenção de backups agora deve ser gerenciada manualmente na página de Releases do GitHub.
# Isso evita a exclusão acidental de backups importantes por um script.

echo "INFO: Processo de backup e upload finalizado com sucesso."

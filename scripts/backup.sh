#!/bin/bash
#
# SCRIPT: backup.sh
# DESCRIÇÃO: Realiza o backup compactado das configurações do OpenVPN e dos perfis de cliente.
# USO: sudo ./backup.sh
#
# DATA: 2025-07-08
# CRIADO POR: Gemini CLI

# --- Validação de Segurança ---
if [ "$EUID" -ne 0 ]; then
  echo "ERRO: Este script precisa ser executado como root (ou com sudo) para acessar todos os arquivos." >&2
  exit 1
fi

# --- Variáveis ---
# Diretórios e arquivos para fazer backup
SOURCE_DIRS="/etc/openvpn /home/pi/idVPN-Core/profiles" 

# Diretório de destino para os backups
BACKUP_DIR="/home/pi/idVPN-Core/backups"
# Formato do nome do arquivo de backup com data e hora
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILENAME="idvpn-backup-${TIMESTAMP}.tar.gz"
BACKUP_FILE_PATH="${BACKUP_DIR}/${BACKUP_FILENAME}"

# Configuração de retenção (quantos backups manter)
RETENTION_DAYS=7

# --- Lógica Principal ---
echo "INFO: Iniciando o processo de backup..."

# Verifica se o diretório de backup existe, senão o cria.
if [ ! -d "$BACKUP_DIR" ]; then
  echo "INFO: Diretório de backup não encontrado. Criando em ${BACKUP_DIR}..."
  mkdir -p "$BACKUP_DIR"
  chown pi:pi "$BACKUP_DIR"
fi

# Cria o arquivo de backup compactado
echo "INFO: Criando o arquivo de backup: ${BACKUP_FILENAME}..."
if tar -czf "${BACKUP_FILE_PATH}" ${SOURCE_DIRS}; then
  echo "SUCESSO: Backup criado em ${BACKUP_FILE_PATH}"
else
  echo "ERRO: Falha ao criar o arquivo de backup." >&2
  exit 1
fi

# --- Lógica de Retenção ---
echo "INFO: Verificando e limpando backups antigos (mais de ${RETENTION_DAYS} dias)..."
# O comando 'find' procura por arquivos no diretório de backup que correspondem ao padrão de nome,
# que são mais antigos que RETENTION_DAYS e os remove.
find "${BACKUP_DIR}" -name "idvpn-backup-*.tar.gz" -mtime +"${RETENTION_DAYS}" -exec rm {} \;

echo "INFO: Limpeza de backups antigos concluída."
echo "INFO: Processo de backup finalizado."

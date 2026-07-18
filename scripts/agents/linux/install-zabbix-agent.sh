#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================================
# Instalação do Zabbix Agent 2
# Sistemas suportados neste projeto:
# - Ubuntu Server 22.04
# - Ubuntu Server 24.04
# ==========================================================

ZABBIX_VERSION="${ZABBIX_VERSION:-7.0}"
ZABBIX_SERVER_IP="${ZABBIX_SERVER_IP:-}"
HOST_NAME="${HOST_NAME:-$(hostname -f 2>/dev/null || hostname)}"

log() {
    echo
    echo "=========================================================="
    echo "$1"
    echo "=========================================================="
}

error_exit() {
    echo "ERRO: $1" >&2
    exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
    error_exit "Execute este script com sudo."
fi

if [[ ! -f /etc/os-release ]]; then
    error_exit "Não foi possível identificar o sistema operacional."
fi

source /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    error_exit "Este script foi preparado para Ubuntu Server."
fi

if [[ "${VERSION_ID}" != "22.04" && "${VERSION_ID}" != "24.04" ]]; then
    error_exit "Versão não suportada. Utilize Ubuntu 22.04 ou 24.04."
fi

if [[ -z "${ZABBIX_SERVER_IP}" ]]; then
    read -r -p "Digite o IP ou DNS do Zabbix Server: " ZABBIX_SERVER_IP
fi

if [[ -z "${ZABBIX_SERVER_IP}" ]]; then
    error_exit "O endereço do Zabbix Server é obrigatório."
fi

read -r -p "Nome do host no Zabbix [${HOST_NAME}]: " INFORMED_HOST_NAME
HOST_NAME="${INFORMED_HOST_NAME:-${HOST_NAME}}"

ARCH="$(dpkg --print-architecture)"

if [[ "${ARCH}" != "amd64" && "${ARCH}" != "arm64" ]]; then
    error_exit "Arquitetura não suportada: ${ARCH}"
fi

REPOSITORY_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+ubuntu${VERSION_ID}_all.deb"
REPOSITORY_FILE="/tmp/zabbix-release.deb"
CONFIG_FILE="/etc/zabbix/zabbix_agent2.conf"

log "1. Atualizando a lista de pacotes"

apt-get update

log "2. Instalando dependências"

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wget \
    ca-certificates

log "3. Adicionando o repositório oficial do Zabbix"

wget -qO "${REPOSITORY_FILE}" "${REPOSITORY_URL}"
dpkg -i "${REPOSITORY_FILE}"
apt-get update

log "4. Instalando o Zabbix Agent 2"

DEBIAN_FRONTEND=noninteractive apt-get install -y zabbix-agent2

log "5. Criando backup da configuração"

cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"

log "6. Configurando o agente"

sed -i "s|^Server=.*|Server=${ZABBIX_SERVER_IP}|" "${CONFIG_FILE}"
sed -i "s|^ServerActive=.*|ServerActive=${ZABBIX_SERVER_IP}|" "${CONFIG_FILE}"
sed -i "s|^Hostname=.*|Hostname=${HOST_NAME}|" "${CONFIG_FILE}"

log "7. Configurando o firewall"

if command -v ufw >/dev/null 2>&1; then
    ufw allow from "${ZABBIX_SERVER_IP}" to any port 10050 proto tcp
fi

log "8. Validando a configuração"

zabbix_agent2 -t agent.ping

log "9. Iniciando o serviço"

systemctl enable --now zabbix-agent2
systemctl restart zabbix-agent2

log "10. Verificando o serviço"

if systemctl is-active --quiet zabbix-agent2; then
    echo "[OK] Zabbix Agent 2 está ativo."
else
    systemctl status zabbix-agent2 --no-pager
    error_exit "O Zabbix Agent 2 não iniciou corretamente."
fi

echo
echo "Instalação concluída."
echo "Nome do host: ${HOST_NAME}"
echo "Zabbix Server: ${ZABBIX_SERVER_IP}"
echo "Porta passiva do agente: 10050"
echo
echo "Cadastre no painel do Zabbix exatamente este nome:"
echo "${HOST_NAME}"
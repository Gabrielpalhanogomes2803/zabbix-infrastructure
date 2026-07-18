#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================================
# Instalação automatizada do Zabbix Server 7.0 LTS
# Sistema operacional: Ubuntu Server 24.04 LTS
# Banco de dados: MariaDB
# Servidor web: Nginx
# ==========================================================

ZABBIX_VERSION="7.0"
TIMEZONE="${TIMEZONE:-America/Sao_Paulo}"

DB_NAME="${DB_NAME:-zabbix}"
DB_USER="${DB_USER:-zabbix}"
DB_PASSWORD="${DB_PASSWORD:-}"

ZABBIX_REPO_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+ubuntu24.04_all.deb"
ZABBIX_REPO_FILE="/tmp/zabbix-release.deb"

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

# O script precisa ser executado como root.
if [[ "${EUID}" -ne 0 ]]; then
    error_exit "Execute este script com sudo."
fi

# Confirma se o sistema é Ubuntu 24.04.
if [[ ! -f /etc/os-release ]]; then
    error_exit "Não foi possível identificar o sistema operacional."
fi

source /etc/os-release

if [[ "${ID}" != "ubuntu" || "${VERSION_ID}" != "24.04" ]]; then
    error_exit "Este script foi preparado somente para Ubuntu 24.04."
fi

# Solicita a senha sem exibi-la no terminal.
if [[ -z "${DB_PASSWORD}" ]]; then
    read -r -s -p "Digite uma senha forte para o banco do Zabbix: " DB_PASSWORD
    echo

    if [[ -z "${DB_PASSWORD}" ]]; then
        error_exit "A senha do banco não pode ficar vazia."
    fi
fi

log "1. Atualizando o sistema"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

log "2. Instalando pacotes necessários"

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    wget \
    curl \
    ca-certificates \
    gnupg \
    mariadb-server \
    nginx \
    ufw

log "3. Configurando o repositório oficial do Zabbix"

wget -qO "${ZABBIX_REPO_FILE}" "${ZABBIX_REPO_URL}"
dpkg -i "${ZABBIX_REPO_FILE}"
apt-get update

log "4. Instalando Zabbix Server, frontend e Agent 2"

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-nginx-conf \
    zabbix-sql-scripts \
    zabbix-agent2

log "5. Inicializando o MariaDB"

systemctl enable --now mariadb

log "6. Criando banco de dados e usuário do Zabbix"

mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_bin;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
    IDENTIFIED BY '${DB_PASSWORD}';

ALTER USER '${DB_USER}'@'localhost'
    IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES
    ON \`${DB_NAME}\`.*
    TO '${DB_USER}'@'localhost';

SET GLOBAL log_bin_trust_function_creators = 1;

FLUSH PRIVILEGES;
SQL

log "7. Importando o banco inicial do Zabbix"

if ! mysql \
    --user="${DB_USER}" \
    --password="${DB_PASSWORD}" \
    "${DB_NAME}" \
    -e "SHOW TABLES LIKE 'users';" |
    grep -q "users"; then

    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz |
        mysql \
            --user="${DB_USER}" \
            --password="${DB_PASSWORD}" \
            "${DB_NAME}"
else
    echo "O banco do Zabbix já parece estar importado."
fi

mysql -e "SET GLOBAL log_bin_trust_function_creators = 0;"

log "8. Configurando o Zabbix Server"

sed -i \
    "s|^# DBPassword=.*|DBPassword=${DB_PASSWORD}|" \
    /etc/zabbix/zabbix_server.conf

if ! grep -q "^DBPassword=" /etc/zabbix/zabbix_server.conf; then
    echo "DBPassword=${DB_PASSWORD}" \
        >> /etc/zabbix/zabbix_server.conf
fi

log "9. Configurando Nginx e PHP"

sed -i \
    's|^[[:space:]]*# listen[[:space:]]*8080;|        listen 80;|' \
    /etc/zabbix/nginx.conf

sed -i \
    's|^[[:space:]]*# server_name[[:space:]]*example.com;|        server_name _;|' \
    /etc/zabbix/nginx.conf

PHP_FPM_CONFIG="/etc/zabbix/php-fpm.conf"

if grep -q "^php_value\\[date.timezone\\]" "${PHP_FPM_CONFIG}"; then
    sed -i \
        "s|^php_value\\[date.timezone\\].*|php_value[date.timezone] = ${TIMEZONE}|" \
        "${PHP_FPM_CONFIG}"
else
    echo "php_value[date.timezone] = ${TIMEZONE}" \
        >> "${PHP_FPM_CONFIG}"
fi

log "10. Configurando firewall"

ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 10051/tcp
ufw --force enable

log "11. Iniciando os serviços"

systemctl enable --now \
    zabbix-server \
    zabbix-agent2 \
    nginx

systemctl restart \
    zabbix-server \
    zabbix-agent2 \
    nginx

log "12. Verificando os serviços"

SERVICES=(
    mariadb
    nginx
    zabbix-server
    zabbix-agent2
)

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "${service}"; then
        echo "[OK] ${service} está ativo."
    else
        echo "[ERRO] ${service} não iniciou corretamente."
        systemctl status "${service}" --no-pager || true
    fi
done

SERVER_IP="$(hostname -I | awk '{print $1}')"

log "Instalação finalizada"

echo "Acesse o painel em:"
echo "http://${SERVER_IP}"
echo
echo "Dados da configuração inicial:"
echo "Banco: ${DB_NAME}"
echo "Usuário: ${DB_USER}"
echo "Host do banco: localhost"
echo
echo "Login inicial padrão do Zabbix:"
echo "Usuário: Admin"
echo "Senha: zabbix"
echo
echo "Troque a senha padrão imediatamente após o primeiro acesso."
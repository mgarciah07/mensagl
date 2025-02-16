#!/bin/bash
set -e  # Detener el script si hay un error

# Añadir el repositorio de PostgreSQL 17
sudo apt install wget -y
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee -a /etc/apt/trusted.gpg.d/pgdg.asc
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

# Actualizar e instalar PostgreSQL 17
sudo apt update -y
sudo apt install postgresql-17 postgresql-client -y

# Validar direcciones IP
validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ ! $ip =~ $regex ]]; then
        echo "Dirección IP no válida: $ip"
        exit 1
    fi
}

# Obtener IPs del usuario
echo "Paso 1"
read -p "Red del servidor de comunicaciones (ej: 192.168.100.0/24): " RED

echo "Paso 2"
read -p "IP del servidor maestro (esta máquina): " PRIMARY_IP
validate_ip $PRIMARY_IP

echo "Paso 3"
read -p "IP del servidor esclavo: " SECONDARY_IP
validate_ip $SECONDARY_IP

# Configuración de PostgreSQL
REPMGR_DB="repmgr"
REPMGR_USER="repmgr"
NODE_NAME="pg1"
DATA_DIR="/var/lib/postgresql/17/main"
REPMGR_CONF="/etc/repmgr.conf"
POSTGRES_VERSION="17"
SYNAPSE_USER="synapse_user"
DB_SYNAPSE="synapse"

# Instalar y configurar repmgr
sudo apt install -y postgresql-17-repmgr
sudo systemctl restart postgresql

# Asignar contraseña al usuario postgres
sudo passwd postgres

# Habilitar autenticación por contraseña en SSH
sudo sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Configurar claves SSH para replicación
sudo -u postgres ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa
sudo -u postgres ssh-copy-id postgres@$SECONDARY_IP

# Configurar PostgreSQL
sudo bash -c "cat >> /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf" <<EOF
shared_preload_libraries = 'repmgr'
wal_level = replica
archive_mode = on
archive_command = '/bin/true'
max_wal_senders = 10
max_replication_slots = 10
hot_standby = on
listen_addresses = '*'
wal_log_hints = on
password_encryption = scram-sha-256
EOF

# Configurar pg_hba.conf
sudo bash -c "cat >> /etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf" <<EOF
local   replication   $REPMGR_USER                                   md5
host    replication   $REPMGR_USER     127.0.0.1/32                  md5
host    replication   $REPMGR_USER     $PRIMARY_IP/32                md5
host    replication   $REPMGR_USER     $SECONDARY_IP/32              md5
host    all             all            $RED                          md5
EOF

# Reiniciar PostgreSQL
sudo systemctl restart postgresql

# Crear archivo de configuración de repmgr
sudo bash -c "cat > $REPMGR_CONF" <<EOF
node_id=1
node_name=$NODE_NAME
conninfo='host=$PRIMARY_IP user=$REPMGR_USER dbname=$REPMGR_DB connect_timeout=2'
data_directory='$DATA_DIR'
failover=automatic
promote_command='repmgr -f $REPMGR_CONF standby promote --log-to-file'
follow_command='repmgr -f $REPMGR_CONF standby follow --log-to-file'
log_file='/var/log/postgresql/repmgr.log'
use_replication_slots=1
EOF

# Registrar el servidor principal en repmgr
sudo -u postgres repmgr -f $REPMGR_CONF primary register
sudo -u postgres repmgr -f $REPMGR_CONF cluster show

# Iniciar repmgrd
echo "Iniciando el daemon de repmgr..."
sudo -u postgres repmgrd -f $REPMGR_CONF -d

echo "¡Configuración del servidor maestro completada!"


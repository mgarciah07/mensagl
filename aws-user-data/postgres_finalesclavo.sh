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
read -p "IP del servidor maestro: " PRIMARY_IP
validate_ip $PRIMARY_IP

echo "Paso 2"
read -p "IP de este servidor esclavo: " SECONDARY_IP
validate_ip $SECONDARY_IP

# Configuración de PostgreSQL
REPMGR_DB="repmgr"
REPMGR_USER="repmgr"
NODE_NAME="pg2"
DATA_DIR="/var/lib/postgresql/17/main"
REPMGR_CONF="/etc/repmgr.conf"
POSTGRES_VERSION="17"

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
sudo -u postgres ssh-copy-id postgres@$PRIMARY_IP

# Modificar configuración de PostgreSQL
sudo systemctl stop postgresql
sudo rm -rf $DATA_DIR

# Clonar el servidor esclavo desde el maestro
sudo -u postgres repmgr -h $PRIMARY_IP -U $REPMGR_USER -d $REPMGR_DB -f $REPMGR_CONF standby clone --copy-external-config-files

# Configurar repmgr.conf
sudo bash -c "cat > $REPMGR_CONF" <<EOF
node_id=2
node_name=$NODE_NAME
conninfo='host=$SECONDARY_IP user=$REPMGR_USER dbname=$REPMGR_DB connect_timeout=2'
data_directory='$DATA_DIR'
failover=automatic
promote_command='repmgr -f $REPMGR_CONF standby promote --log-to-file'
follow_command='repmgr -f $REPMGR_CONF standby follow --log-to-file'
log_file='/var/log/postgresql/repmgr.log'
use_replication_slots=1
EOF

# Reiniciar PostgreSQL
sudo systemctl start postgresql

# Registrar el servidor esclavo en repmgr
sudo -u postgres repmgr -f $REPMGR_CONF standby register
sudo -u postgres repmgr -f $REPMGR_CONF cluster show

# Iniciar repmgrd
echo "Iniciando el daemon de repmgr..."
sudo -u postgres repmgrd -f $REPMGR_CONF -d

echo "¡Configuración del servidor esclavo completada!"


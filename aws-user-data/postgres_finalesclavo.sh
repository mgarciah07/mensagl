#!/bin/bash

# Add PostgreSQL APT repository
sudo apt install wget -y
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee -a /etc/apt/trusted.gpg.d/pgdg.asc

# Add the repository
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

# Update and install PostgreSQL 17
sudo apt update -y
sudo apt install postgresql-17 -y
sudo apt-get install postgresql-client
sudo systemctl enable postgresql
clear

read -p "Dime la ip del servidor maestro: " PRIMARY_IP
clear

read -p "Dime la ip del servidor esclavo (LA IP DE ESTA MAQUINA): " STANDBY_IP
clear

# Variables configurables
USUARIO="ubuntu"
REPMGR_DB="repmgr"
REPMGR_USER="repmgr"
NODE_NAME="pg2"
DATA_DIR="/var/lib/postgresql/17/main"
REPMGR_CONF="/etc/repmgr.conf"
POSTGRES_VERSION="17"          # Cambia esto si tienes una versión diferente

# Función para ejecutar como usuario postgres
exec_as_postgres() {
    sudo -u postgres bash -c "$1"
}

# Actualizar y instalar PostgreSQL y repmgr
echo "Instalando PostgreSQL y repmgr..."
sudo apt update
sudo apt install -y postgresql-17-repmgr
sudo systemctl enable postgresql
clear

# Asignar contraseña al usuario postgres
echo "Asignando contraseña al usuario postgres..."
sudo passwd postgres
clear

read  -p "Entra a tu otra maquina donde quieres tener el sevidor maestro y finaliza la instalacion, cuando termine, haz click en enter: "
echo "¡Has presionado Enter! Continuando con el script..."

# Configurar claves SSH para replicación con el maestro
echo "Generando claves SSH para replicación con el maestro..."
exec_as_postgres "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa"
exec_as_postgres "ssh-copy-id postgres@$PRIMARY_IP"
clear


# Modificar postgresql.conf
echo "Configurando postgresql.conf..."
sudo sed -i "/^#data_directory/c\data_directory = '$DATA_DIR'" /etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf
clear

# Reiniciar servicio PostgreSQL
echo "Reiniciando servicio PostgreSQL..."
sudo systemctl restart postgresql


# Crear archivo de configuración de repmgr
echo "Creando archivo de configuración de repmgr en $REPMGR_CONF..."
sudo bash -c "cat > $REPMGR_CONF" <<EOF
node_id=2
node_name=$NODE_NAME
conninfo='host=$STANDBY_IP user=$REPMGR_USER dbname=$REPMGR_DB connect_timeout=2'
data_directory='$DATA_DIR'
failover=automatic
promote_command='repmgr -f $REPMGR_CONF standby promote --log-to-file --siblings-follow --verbose'
follow_command='repmgr -f $REPMGR_CONF standby follow --log-to-file'
log_file='/var/log/postgresql/repmgr.log'
use_replication_slots=1  # Usar replication slots
EOF

sudo rm -rf /var/lib/postgresql/17/main/

# Clonar el servidor standby desde el maestro utilizando repmgr
echo "Clonando el nodo standby desde el nodo maestro..."
exec_as_postgres "repmgr -h $PRIMARY_IP -U $REPMGR_USER -d $REPMGR_DB -f $REPMGR_CONF standby clone --copy-external-config-files"
clear

sudo -u $USUARIO sudo systemctl restart postgresql
clear

# Registrar el servidor standby en repmgr
echo "Registrando el servidor standby en repmgr..."
exec_as_postgres "repmgr -f /etc/repmgr.conf standby register"
exec_as_postgres "repmgr -f $REPMGR_CONF cluster show"

# Iniciar repmgrd (daemon)
echo "Iniciando el daemon de repmgr..."
exec_as_postgres "repmgrd -f $REPMGR_CONF -d"

echo "¡Configuración de PostgreSQL con repmgr en el servidor standby completada!"

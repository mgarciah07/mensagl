#!/bin/bash

######## Verificar si el script esta siendo ejecutado por el usuario root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ser ejecutado como root."
    exit 1  # Salir con un codigo de error
else
echo "Eres root. Ejecutando el comando..."

# Actualiza la lista de paquetes
apt update

# Instala rsync si no está instalado
apt install -y rsync

# Instala AWS CLI si no está instalado
apt install -y awscli

# Crea el archivo de script de respaldo
cat <<EOF > /home/ubuntu/backup-postgres.sh

#!/bin/bash

# Variables
BACKUP_DIR="/home/ubuntu/backups"
INCREMENTAL_DIR="/home/postgres/backups-incremental"
DATE=$(date +%Y-%m-%d)
S3_BUCKET="s3://s3-mensagl-marcos"

# Crear directorio de backups incrementales si no existe
mkdir -p "${INCREMENTAL_DIR}"

# Sincronizar cambios incrementales al directorio incremental
rsync -av --delete "${BACKUP_DIR}/" "${INCREMENTAL_DIR}/" || { echo "Error en rsync"; exit 1; }

# Comprimir el directorio incremental
tar -czf "${INCREMENTAL_DIR}/backup_${DATE}.tar.gz" -C "${INCREMENTAL_DIR}" . || { echo "Error al comprimir"; exit 1; }

# Transferir la copia de seguridad a S3
aws s3 cp "${INCREMENTAL_DIR}/backup_${DATE}.tar.gz" "${S3_BUCKET}/backup_${DATE}.tar.gz" || { echo "Error al subir a S3"; exit 1; }

EOF

# Asegura que el archivo de backup sea ejecutable
chmod 700 /home/ubuntu/backup-postgres.sh

# Configura la tarea cron para ejecutar el backup a las 2:00 AM todos los días
tarea="0 2 * * * /home/ubuntu/backup-postgres.sh >/dev/null 2>&1"

# Añade la tarea cron al crontab actual, sin duplicar
(crontab -l 2>/dev/null; echo "$tarea") | crontab -

fi
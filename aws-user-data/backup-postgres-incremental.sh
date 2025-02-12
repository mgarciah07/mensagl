#!/bin/bash
apt update
apt install rsync -y

cat <<EOF > /home/postgres/backup-postgres.sh

#!/bin/bash

# Variables
BACKUP_DIR="/home/postgres/backups"
DATE=$(date +%Y-%m-%d)
FILENAME="backup_${DATE}.tar.gz"
S3_BUCKET="s3://tu-bucket-de-s3"

# Crear la copia de seguridad
pg_dump -U usuario -h host -d base_de_datos --format=directory -f "${BACKUP_DIR}/${FILENAME}"

# Transferir la copia de seguridad a S3
aws s3 cp "${BACKUP_DIR}/${FILENAME}" "${S3_BUCKET}/${FILENAME}"

EOF

chmod 700 /home/postgres/backup-postgres.sh

tarea="0 2 * * * /ruta/a/tu/script.sh >/dev/null 2>&1"
# Añade la tarea cron al crontab actual
(crontab -l 2>/dev/null; echo "$tarea") | crontab -

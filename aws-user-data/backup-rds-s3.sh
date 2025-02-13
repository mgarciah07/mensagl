#!/bin/bash

######## Verificar si el script está siendo ejecutado por el usuario root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ser ejecutado como root."
    exit 1  # Salir con un código de error
else
    echo "Eres root. Ejecutando el comando..."

    # Actualiza la lista de paquetes
    apt update

    # Verifica si mysqldump está instalado
    if ! command -v mysqldump &> /dev/null; then
        apt install -y mysql-client
    fi

    # Verifica si AWS CLI está instalado
    if ! command -v aws &> /dev/null; then
        apt install -y awscli
    fi

    # Variables
    MYSQL_USER="wordpress"
    MYSQL_PASSWORD="Admin123"
    MYSQL_HOST="instancias-reto-mysqlrds-nyoyclo3kfeh.cwvnqbc5y9vt.us-east-1.rds.amazonaws.com"
    MYSQL_DB="wordpress"
    AWS_BUCKET="s3://s3-mensagl-marcos"
    BACKUP_DIR="/home/ubuntu/backups"
    DATE=$(date +%Y-%m-%d)
    LOG_FILE="/var/log/backup-mysql.log"

    # Crea el archivo de script de respaldo
    cat <<EOF > /home/ubuntu/backup-mysql.sh
#!/bin/bash

# Especificar la ubicación del archivo de credenciales de AWS
export AWS_SHARED_CREDENTIALS_FILE="/home/ubuntu/.aws/credentials"

# Variables
BACKUP_DIR="${BACKUP_DIR}"
DATE=${DATE}
S3_BUCKET="${AWS_BUCKET}"
LOG_FILE="${LOG_FILE}"
MYSQL_USER="${MYSQL_USER}"
MYSQL_PASSWORD="${MYSQL_PASSWORD}"
MYSQL_HOST="${MYSQL_HOST}"
MYSQL_DB="${MYSQL_DB}"

# Crear directorio de backups si no existe
mkdir -p "\${BACKUP_DIR}"

# Realizar respaldo de la base de datos MySQL
mysqldump -h \${MYSQL_HOST} -u \${MYSQL_USER} -p'\${MYSQL_PASSWORD}' \${MYSQL_DB} > "\${BACKUP_DIR}/mysql_backup_\${DATE}.sql" || { echo "Error al realizar el backup de MySQL" >> "\${LOG_FILE}"; exit 1; }

# Comprimir el archivo de respaldo
tar -czf "\${BACKUP_DIR}/mysql_backup_\${DATE}.tar.gz" -C "\${BACKUP_DIR}" "mysql_backup_\${DATE}.sql" || { echo "Error al comprimir" >> "\${LOG_FILE}"; exit 1; }

# Transferir la copia de seguridad a S3
aws s3 cp "\${BACKUP_DIR}/mysql_backup_\${DATE}.tar.gz" "\${S3_BUCKET}/mysql_backup_\${DATE}.tar.gz" || { echo "Error al subir a S3" >> "\${LOG_FILE}"; exit 1; }

EOF

    # Asegura que el archivo de backup sea ejecutable
    chmod +x /home/ubuntu/backup-mysql.sh
    
    # Configura la tarea cron para ejecutar el backup a las 3:00 AM todos los días
    tarea="0 3 * * * /home/ubuntu/backup-mysql.sh >> /var/log/backup-mysql.log 2>&1"

    # Añade la tarea cron al crontab actual, sin duplicar
    (crontab -l 2>/dev/null | grep -v -F "$tarea"; echo "$tarea") | crontab -
fi


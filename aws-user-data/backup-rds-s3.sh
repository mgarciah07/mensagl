#!/bin/bash

# Variables
DB_INSTANCE_IDENTIFIER="your-rds-instance-identifier"
S3_BUCKET_NAME="your-s3-bucket-name"
BACKUP_DIR="/path/to/backup/dir"
TIMESTAMP=$(date +"%F")
BACKUP_FILE="$BACKUP_DIR/db_backup_$TIMESTAMP.sql"

# Crear un snapshot de la instancia RDS
aws rds create-db-snapshot --db-instance-identifier $DB_INSTANCE_IDENTIFIER --db-snapshot-identifier "snapshot-$TIMESTAMP"

# Esperar a que el snapshot se complete (opcional, basado en tus necesidades)
sleep 300

# Exportar el snapshot a S3
aws rds export-db-snapshot-to-s3 --source-db-snapshot-identifier "snapshot-$TIMESTAMP" --s3-bucket-name $S3_BUCKET_NAME --s3-prefix "backups/$TIMESTAMP"

# Eliminar el snapshot local después de la exportación (opcional)
aws rds delete-db-snapshot --db-snapshot-identifier "snapshot-$TIMESTAMP"

echo "Backup completed and stored in S3: s3://$S3_BUCKET_NAME/backups/$TIMESTAMP"

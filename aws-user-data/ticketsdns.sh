#!/bin/bash

######## Verificar si el script esta siendo ejecutado por el usuario root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ser ejecutado como root."
    exit 1  # Salir con un codigo de error
else
echo "Eres root. Ejecutando el comando..."

mkdir duckdns
cd duckdns

# Poner entre las comillas el echo url=...
echo 'echo url="https://www.duckdns.org/update?domains=marcosticket&token=899e823b-dbdf-4fda-ba95-5138dc4939b7&ip=" | curl -k -o ~/duckdns/duck.log -K -'>duck.sh
chmod 700 duck.sh


tarea="*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1"
# Añade la tarea cron al crontab actual
(crontab -l 2>/dev/null; echo "$tarea") | crontab -

./duck.sh

fi
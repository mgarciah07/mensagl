#!/bin/bash

mkdir duckdns
cd duckdns

# Poner entre las comillas el echo url=...
echo 'echo url="https://www.duckdns.org/update?domains=marcosticket&token=899e823b-dbdf-4fda-ba95-5138dc4939b7&ip=" | curl -k -o ~/duckdns/duck.log -K -'>duck.sh
chmod 700 duck.sh


tarea="*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1"
# Añade la tarea cron al crontab actual
(crontab -l 2>/dev/null; echo "$tarea") | crontab -

./duck.sh
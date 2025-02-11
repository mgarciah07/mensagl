#!/bin/bash
######## Verificar si el script esta siendo ejecutado por el usuario root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ser ejecutado como root."
    exit 1  # Salir con un codigo de error
else
echo "Eres root. Ejecutando el comando..."

# Actualizamos el sistema
apt-get update -y
apt-get upgrade -y

# Instalamos mdadm
apt-get install mdadm -y

# Detectamos los dispositivos EBS de 30 GB usando lsblk y grep
DISKS=$(lsblk -o NAME,SIZE | grep "30G" | awk '{print "/dev/"$1}')

# Creamos el RAID1 con los dispositivos detectados
yes | mdadm --create --verbose /dev/md0 --level=1 --name=RAID1 --raid-devices=2 $(echo $DISKS | awk '{print $1, $2}')

# Creamos el sistema de archivos en el RAID
mkfs.ext4 -F /dev/md0

# Creamos un punto de montaje y montamos el RAID
mkdir -p /mnt/raid
mount /dev/md0 /mnt/raid

# Agregamos el RAID a /etc/fstab para montaje automático
echo '/dev/md0 /mnt/raid ext4 defaults,nofail,discard 0 0' >> /etc/fstab

fi
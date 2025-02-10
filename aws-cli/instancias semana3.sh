#!/bin/bash

# Definir variables
key_name="ssh-mensagl-2025-marcos"
ami_Ubuntu_22_04="ami-0e1bed4f06a3b463d"  # Reemplaza con el ID de la AMI de Ubuntu que desees usar
ami_Ubuntu_24_04="ami-04b4f1a9cf54c11d0"  
instance_type="t2.micro"
region="us-east-1"

# Desactivar paginación en AWS CLI
export AWS_PAGER=""

# Obtener IDs de subredes y VPC
vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos" --query "Vpcs[0].VpcId" --output text)
subnet_public1_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos-subnet-public1-us-east-1a" --query "Subnets[0].SubnetId" --output text)
subnet_public2_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos-subnet-public2-us-east-1b" --query "Subnets[0].SubnetId" --output text)
subnet_private1_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos-subnet-private1-us-east-1a" --query "Subnets[0].SubnetId" --output text)
subnet_private2_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos-subnet-private2-us-east-1b" --query "Subnets[0].SubnetId" --output text)

# Crear el grupo de subredes RDS
aws rds create-db-subnet-group --db-subnet-group-name "rds-subnet-group-mensagl-2025" --db-subnet-group-description "Subnet group for RDS instances" --subnet-ids "$subnet_private1_id $subnet_private2_id"

# Crear grupos de seguridad
sg_haproxy_id=$(aws ec2 create-security-group --group-name "sg_HAProxy" --description "Security group for HAProxy" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_haproxy_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_haproxy_id" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_haproxy_id" --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_haproxy_id" --protocol tcp --port 8080 --cidr 0.0.0.0/0

sg_matrix_synapse_id=$(aws ec2 create-security-group --group-name "sg_Matrix-Synapse" --description "Security group for Matrix-Synapse" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 8008 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 8448 --cidr 0.0.0.0/0

sg_wordpress_id=$(aws ec2 create-security-group --group-name "sg_wordpress" --description "Security group for Wordpress" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_wordpress_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_wordpress_id" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_wordpress_id" --protocol tcp --port 443 --cidr 0.0.0.0/0

sg_postgres_id=$(aws ec2 create-security-group --group-name "sg_postgres" --description "Security group for Postgres" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_postgres_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_postgres_id" --protocol tcp --port 5432 --cidr 0.0.0.0/0

sg_mysqlrds_id=$(aws ec2 create-security-group --group-name "sg_mysqlrds" --description "Security group for mysqlrds" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_mysqlrds_id" --protocol tcp --port 3633 --cidr 0.0.0.0/0

sg_nas_id=$(aws ec2 create-security-group --group-name "sg_nas" --description "Security group for NAS" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_nas_id" --protocol tcp --port 22 --cidr 0.0.0.0/0

# Crear instancias HAProxy en subredes públicas
aws ec2 run-instances --image-id "$ami_Ubuntu_24_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_haproxy_id" --subnet-id "$subnet_public1_id" --private-ip-address "10.210.1.10" --associate-public-ip-address --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=HAProxyMatrix}]' --user-data file://script.sh
aws ec2 run-instances --image-id "$ami_Ubuntu_24_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_haproxy_id" --subnet-id "$subnet_public2_id" --private-ip-address "10.210.2.10" --associate-public-ip-address--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=HAProxyWordpress}]' --user-data file://script.sh

# Crear instancias Matrix-Synapse en subredes privadas
aws ec2 run-instances --image-id "$ami_Ubuntu_24_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_matrix_synapse_id" --subnet-id "$subnet_private1_id" --private-ip-address "10.210.3.20" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Matrix-Synapse1}]' --user-data file://script.sh
aws ec2 run-instances --image-id "$ami_Ubuntu_24_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_matrix_synapse_id" --subnet-id "$subnet_private2_id" --private-ip-address "10.210.3.21" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Matrix-Synapse2}]' --user-data file://script.sh

# Crear instancias Wordpress en subredes privadas
aws ec2 run-instances --image-id "$ami_Ubuntu_24_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_wordpress_id" --subnet-id "$subnet_private1_id" --private-ip-address "10.210.4.20" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Wordpress1}]' --user-data file://script.sh
aws ec2 run-instances --image-id "$ami_Ubuntu_24_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_wordpress_id" --subnet-id "$subnet_private2_id" --private-ip-address "10.210.4.21" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Wordpress2}]' --user-data file://script.sh

# Crear instancias PostgreSQL en subredes privadas
aws ec2 run-instances --image-id "$ami_Ubuntu_22_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_postgres_id" --subnet-id "$subnet_private1_id" --private-ip-address "10.210.3.100" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Postgres1}]' --user-data file://script.sh
aws ec2 run-instances --image-id "$ami_Ubuntu_22_04" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_postgres_id" --subnet-id "$subnet_private2_id" --private-ip-address "10.210.3.101" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Postgres2}]' --user-data file://script.sh

# Crear RDS MySQL para Wordpress
aws rds create-db-instance --db-instance-identifier mysql-Wordpress --db-instance-class db.t3.micro --engine mysql --master-username admin --master-user-password password --allocated-storage 20 --vpc-security-group-ids "$sg_mysqlrds_id" --db-subnet-group-name "$subnet_private1_id"

# Crear bucket S3 para copias de seguridad
aws s3api create-bucket --bucket "s3-mensagl-marcos" --region "$region"

# Crear NAS porque el S3 no deja subir nada con 2 discos de 30GB
aws ec2 run-instances \
    --image-id "$ami_Ubuntu_24_04" \
    --count 1 \
    --instance-type "$instance_type" \
    --key-name "$key_name" \
    --security-group-ids "$sg_nas_id" \
    --subnet-id "$subnet_private1_id" \
    --private-ip-address "10.210.3.200" \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=NAS}]'\
    --block-device-mappings '[
        {"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30}},
        {"DeviceName":"/dev/xvdb","Ebs":{"VolumeSize":30}}
    ]' \
    --user-data file://../aws-user-data/NAS-raid1.sh

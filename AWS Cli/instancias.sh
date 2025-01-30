#!/bin/bash

# Definir variables
key_name="ssh-mensagl-2025-marcos"
ami_id="ami-04b4f1a9cf54c11d0"  # Reemplaza con el ID de la AMI de Ubuntu que desees usar
instance_type="t2.micro"

# Crear un par de claves
aws ec2 create-key-pair --key-name "$key_name" --query 'KeyMaterial' --output text > "${key_name}.pem"
chmod 400 "${key_name}.pem"

# Obtener IDs de subredes y VPC
vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos" --query "Vpcs[0].VpcId" --output text)
subnet_public1_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos-subnet-public1-us-east-1a" --query "Subnets[0].SubnetId" --output text)
subnet_public2_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos-subnet-public2-us-east-1b" --query "Subnets[0].SubnetId" --output text)
subnet_private1_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos-subnet-private1-us-east-1a" --query "Subnets[0].SubnetId" --output text)
subnet_private2_id=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=vpc-mensagl-2025-Marcos-subnet-private2-us-east-1b" --query "Subnets[0].SubnetId" --output text)

# Crear grupos de seguridad
sg_haproxy_id=$(aws ec2 create-security-group --group-name "sg_HAProxy" --description "Security group for HAProxy" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_haproxy_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_haproxy_id" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_haproxy_id" --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_haproxy_id" --protocol tcp --port 8080 --cidr 0.0.0.0/0

sg_matrix_synapse_id=$(aws ec2 create-security-group --group-name "sg_Matrix-Synapse" --description "Security group for Matrix-Synapse" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 8008 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_matrix_synapse_id" --protocol tcp --port 8448 --cidr 0.0.0.0/0

sg_wordpress_id=$(aws ec2 create-security-group --group-name "sg_wordpress" --description "Security group for Wordpress" --vpc-id "$vpc_id" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id "$sg_wordpress_id" --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_wordpress_id" --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id "$sg_wordpress_id" --protocol tcp --port 443 --cidr 0.0.0.0/0

# Crear instancias HAProxy en subredes públicas
aws ec2 run-instances --image-id "$ami_id" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_haproxy_id" --subnet-id "$subnet_public1_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=HAProxy1}]'
aws ec2 run-instances --image-id "$ami_id" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_haproxy_id" --subnet-id "$subnet_public2_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=HAProxy2}]'

# Crear instancias Matrix-Synapse en subredes privadas
aws ec2 run-instances --image-id "$ami_id" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_matrix_synapse_id" --subnet-id "$subnet_private1_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Matrix-Synapse1}]'
aws ec2 run-instances --image-id "$ami_id" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_matrix_synapse_id" --subnet-id "$subnet_private2_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Matrix-Synapse2}]'

# Crear instancias Wordpress en subredes privadas
aws ec2 run-instances --image-id "$ami_id" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_wordpress_id" --subnet-id "$subnet_private1_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Wordpress1}]'
aws ec2 run-instances --image-id "$ami_id" --count 1 --instance-type "$instance_type" --key-name "$key_name" --security-group-ids "$sg_wordpress_id" --subnet-id "$subnet_private2_id" --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Wordpress2}]'

# Crear RDS PostgreSQL para Matrix-Synapse
aws rds create-db-instance --db-instance-identifier postgres-Matrix --db-instance-class db.t3.micro --engine postgres --master-username admin --master-user-password password --allocated-storage 20 --vpc-security-group-ids "$sg_matrix_synapse_id"

# Crear RDS MySQL para Wordpress
aws rds create-db-instance --db-instance-identifier mysql-Wordpress --db-instance-class db.t3.micro --engine mysql --master-username admin --master-user-password password --allocated-storage 20 --vpc-security-group-ids "$sg_wordpress_id"

# Crear bucket S3 para copias de seguridad
aws s3api create-bucket --bucket copiasSeguridad --region us-east-1

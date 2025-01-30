#!/bin/bash

# Crear VPC
aws ec2 create-vpc --cidr-block "10.0.0.0/16" --instance-tenancy "default" --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=vpc-mensagl-2025-Marcos}]' 

# Habilitar DNS Hostnames
aws ec2 modify-vpc-attribute --vpc-id "vpc-0e2a67f9c37065692" --enable-dns-hostnames '{"Value":true}' 

# Crear subredes
aws ec2 create-subnet --vpc-id "vpc-0e2a67f9c37065692" --cidr-block "10.0.1.0/24" --availability-zone "us-east-1a" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=subnet-public1-us-east-1a}]' 
aws ec2 create-subnet --vpc-id "vpc-0e2a67f9c37065692" --cidr-block "10.0.2.0/24" --availability-zone "us-east-1b" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=subnet-public2-us-east-1b}]' 
aws ec2 create-subnet --vpc-id "vpc-0e2a67f9c37065692" --cidr-block "10.0.3.0/24" --availability-zone "us-east-1a" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=subnet-private1-us-east-1a}]' 
aws ec2 create-subnet --vpc-id "vpc-0e2a67f9c37065692" --cidr-block "10.0.4.0/24" --availability-zone "us-east-1b" --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=subnet-private2-us-east-1b}]' 

# Crear y asociar Internet Gateway
aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw-mensagl-2025}]' 
aws ec2 attach-internet-gateway --internet-gateway-id "igw-00df5c68a45609805" --vpc-id "vpc-0e2a67f9c37065692" 

# Pausa para esperar que el Internet Gateway esté completamente operativo
sleep 10

# Crear tabla de rutas pública
aws ec2 create-route-table --vpc-id "vpc-0e2a67f9c37065692" --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-public}]' 
aws ec2 create-route --route-table-id "rtb-07a6a999e0c95e927" --destination-cidr-block "0.0.0.0/0" --gateway-id "igw-00df5c68a45609805" 

# Asociar tabla de rutas pública con subredes públicas
aws ec2 associate-route-table --route-table-id "rtb-07a6a999e0c95e927" --subnet-id "subnet-060882dcf95477c81" 
aws ec2 associate-route-table --route-table-id "rtb-07a6a999e0c95e927" --subnet-id "subnet-0b266f52a9ef399cf" 

# Crear Elastic IP y NAT Gateway
aws ec2 allocate-address --domain "vpc" --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=eip-us-east-1a}]' 
aws ec2 create-nat-gateway --subnet-id "subnet-060882dcf95477c81" --allocation-id "eipalloc-034e44cad429cb2a9" --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=nat-public1-us-east-1a}]' 

# Crear tablas de rutas privadas
aws ec2 create-route-table --vpc-id "vpc-0e2a67f9c37065692" --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-private1-us-east-1a}]' 
aws ec2 create-route --route-table-id "rtb-03d4664ec39678b0a" --destination-cidr-block "0.0.0.0/0" --nat-gateway-id "nat-0a0584853e13d0efe" 
aws ec2 associate-route-table --route-table-id "rtb-03d4664ec39678b0a" --subnet-id "subnet-0d504a5bd62393094" 

aws ec2 create-route-table --vpc-id "vpc-0e2a67f9c37065692" --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=rtb-private2-us-east-1b}]' 
aws ec2 create-route --route-table-id "rtb-08b84504d22cc930a" --destination-cidr-block "0.0.0.0/0" --nat-gateway-id "nat-0a0584853e13d0efe" 
aws ec2 associate-route-table --route-table-id "rtb-08b84504d22cc930a" --subnet-id "subnet-0f1c4a90cdb30fb2a" 

# Describir VPC y tablas de rutas
aws ec2 describe-vpcs --vpc-ids "vpc-0e2a67f9c37065692"
aws ec2 describe-route-tables --route-table-ids "rtb-03d4664ec39678b0a" "rtb-08b84504d22cc930a"

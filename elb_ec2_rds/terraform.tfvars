### Variables ###

# AWS
access_key = "***YourAccessKey***"
secret_key = "***YourSecretKey***"
region = "ap-northeast-1"

# Name
service_name = "***YourServiceName***"

# Segment
root_segment = "10.10.0.0/16"
public_segment01 = "10.10.10.0/24"
public_segment02 = "10.10.11.0/24"
private_segment01 = "10.10.200.0/24"
private_segment02 = "10.10.201.0/24"

# AZ
public_segment01_az = "ap-northeast-1a"
public_segment02_az = "ap-northeast-1c"
private_segment01_az = "ap-northeast-1a"
private_segment02_az = "ap-northeast-1c"

# SecurityGroup
ssh_allow_ip = "***YourIP/32***"

# KeyPair
public_key = "***ssh-rsa YourPublicKey your@example.com***"
private_key = "***~/.ssh/YourPrivateKey***"

# RDS
db_user = "root"
db_password = "password"

# Variables
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "service_name" {}
variable "root_segment" {}
variable "public_segment01" {}
variable "public_segment02" {}
variable "private_segment01" {}
variable "private_segment02" {}
variable "public_segment01_az" {}
variable "public_segment02_az" {}
variable "private_segment01_az" {}
variable "private_segment02_az" {}
variable "ssh_allow_ip" {}
variable "public_key" {}
variable "private_key" {}
variable "db_user" {}
variable "db_password" {}

# Provider
provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

# VPC
resource "aws_vpc" "vpc_main" {
    cidr_block = "${var.root_segment}"
    tags {
        Name = "${var.service_name}"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "vpc_main-igw" {
    vpc_id = "${aws_vpc.vpc_main.id}"
    tags {
        Name = "${var.service_name} igw"
    }
}

# Public Subnets
resource "aws_subnet" "vpc_main-public-subnet01" {
    vpc_id = "${aws_vpc.vpc_main.id}"
    cidr_block = "${var.public_segment01}"
    availability_zone = "${var.public_segment01_az}"
    tags {
        Name = "${var.service_name} public-subnet01"
    }
}
resource "aws_subnet" "vpc_main-public-subnet02" {
    vpc_id = "${aws_vpc.vpc_main.id}"
    cidr_block = "${var.public_segment02}"
    availability_zone = "${var.public_segment02_az}"
    tags {
        Name = "${var.service_name} public-subnet02"
    }
}

# Private Subnets
resource "aws_subnet" "vpc_main-private-subnet01" {
    vpc_id = "${aws_vpc.vpc_main.id}"
    cidr_block = "${var.private_segment01}"
    availability_zone = "${var.private_segment01_az}"
    tags {
        Name = "${var.service_name} private-subnet01"
    }
}
resource "aws_subnet" "vpc_main-private-subnet02" {
    vpc_id = "${aws_vpc.vpc_main.id}"
    cidr_block = "${var.private_segment02}"
    availability_zone = "${var.private_segment02_az}"
    tags {
        Name = "${var.service_name} private-subnet02"
    }
}

# Routes Table
resource "aws_route_table" "vpc_main-public-rt" {
    vpc_id = "${aws_vpc.vpc_main.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.vpc_main-igw.id}"
    }
    tags {
        Name = "${var.service_name} public-rt"
    }
}
resource "aws_route_table_association" "vpc_main-rta01" {
    subnet_id = "${aws_subnet.vpc_main-public-subnet01.id}"
    route_table_id = "${aws_route_table.vpc_main-public-rt.id}"
}
resource "aws_route_table_association" "vpc_main-rta02" {
    subnet_id = "${aws_subnet.vpc_main-public-subnet02.id}"
    route_table_id = "${aws_route_table.vpc_main-public-rt.id}"
}

# SecurityGroup
resource "aws_security_group" "elb_sg" {
    name = "ELB_SG"
    vpc_id = "${aws_vpc.vpc_main.id}"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    description = "ELB SG"
}
resource "aws_security_group" "app_sg" {
    name = "APP_SG"
    vpc_id = "${aws_vpc.vpc_main.id}"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = ["${aws_security_group.elb_sg.id}"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.ssh_allow_ip}"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    description = "APP SG"
}
resource "aws_security_group" "rds_sg" {
    name = "RDS_SG"
    vpc_id = "${aws_vpc.vpc_main.id}"
    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = ["${aws_security_group.app_sg.id}"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    description = "RDS SG"
}

# ELB
resource "aws_elb" "elb" {
    name = "app-elb"
    subnets = ["${aws_subnet.vpc_main-public-subnet01.id}", "${aws_subnet.vpc_main-public-subnet02.id}"]
    security_groups = ["${aws_security_group.elb_sg.id}"]
    listener {
        instance_port = 80
        instance_protocol = "http"
        lb_port = 80
        lb_protocol = "http"
    }
    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        target = "HTTP:80/health.html"
        interval = 30
    }
    instances = ["${aws_instance.app01.id}", "${aws_instance.app02.id}"]
    cross_zone_load_balancing = true
}

# EC2
resource "aws_instance" "app01" {
    ami = "ami-3bd3c45c"
    instance_type = "t2.micro"
    key_name = "app-key"
    associate_public_ip_address = true
    vpc_security_group_ids = ["${aws_security_group.app_sg.id}"]
    subnet_id = "${aws_subnet.vpc_main-public-subnet01.id}"
    tags {
        Name = "${var.service_name}-app01"
    }
    provisioner "remote-exec" {
        inline = [
            "sudo yum update -y",
            "sudo yum install -y httpd",
            "sudo service httpd start",
            "sudo chkconfig httpd on",
            "sudo touch /var/www/html/health.html"
        ]
    }
    connection {
        user = "ec2-user"
        private_key = "${file("${var.private_key}")}"
    }
}
resource "aws_instance" "app02" {
    ami = "ami-3bd3c45c"
    instance_type = "t2.micro"
    key_name = "app-key"
    associate_public_ip_address = true
    vpc_security_group_ids = ["${aws_security_group.app_sg.id}"]
    subnet_id = "${aws_subnet.vpc_main-public-subnet02.id}"
    tags {
        Name = "${var.service_name}-app02"
    }
    provisioner "remote-exec" {
        inline = [
            "sudo yum update -y",
            "sudo yum install -y httpd",
            "sudo service httpd start",
            "sudo chkconfig httpd on",
            "sudo touch /var/www/html/health.html"
        ]
    }
    connection {
        user = "ec2-user"
        private_key = "${file("${var.private_key}")}"
    }
}

# RDS
resource "aws_db_subnet_group" "rds_dsg" {
    name = "${var.service_name}-db-dsg"
    description = "${var.service_name} MultiAZ"
    subnet_ids = ["${aws_subnet.vpc_main-private-subnet01.id}", "${aws_subnet.vpc_main-private-subnet02.id}"]
}
resource "aws_db_instance" "rds" {
    allocated_storage = 10
    storage_type = "gp2"
    engine = "mysql"
    engine_version = "5.6.35"
    instance_class = "db.t2.micro"
    name = "appDB"
    username = "${var.db_user}"
    password = "${var.db_password}"
    db_subnet_group_name = "${aws_db_subnet_group.rds_dsg.id}"
    parameter_group_name = "default.mysql5.6"
    multi_az = true
    skip_final_snapshot = false
}

# KeyPair
resource "aws_key_pair" "sshkey" {
    key_name = "app-key"
    public_key = "${var.public_key}"
}

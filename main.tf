terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}

provider "aws" {
  region  = "ap-northeast-2"
}

resource "aws_vpc" "groomVPC" {

  cidr_block = var.vpc_cidr
  tags = {
    Name = "groomVPC"
  }
}

# public subnet
resource "aws_subnet" "asm4_public_subnets" {
  count = length(var.cidr_public_subnet)
  vpc_id = aws_vpc.groomVPC.id
  cidr_block = element(var.cidr_public_subnet, count.index)
  availability_zone = element(var.ap_northeast_availability_zone, count.index)

  tags = {
    Name = "Public Web ${element(var.name, count.index)}"
  }
}

# private subnet - for app
resource "aws_subnet" "asm4_private_subnets" {

  count = length(var.cidr_private_subnet)
  vpc_id = aws_vpc.groomVPC.id
  cidr_block = element(var.cidr_private_subnet, count.index)
  availability_zone = element(var.ap_northeast_availability_zone, count.index)

  tags = {
    Name = "Private App ${element(var.name, count.index)}"
  }

}

# private subnet - for db
resource "aws_subnet" "asm4_db_private_subnets" {

  count = length(var.cidr_db_private_subnet)
  vpc_id = aws_vpc.groomVPC.id
  cidr_block = element(var.cidr_db_private_subnet, count.index)
  availability_zone = element(var.ap_northeast_availability_zone, count.index)

  tags = {
    Name = "Private DB ${element(var.name, count.index)}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "public_internet_gateway" {

  vpc_id = aws_vpc.groomVPC.id

  tags = {
    Name = "IGW: For goorm asm4"
  }
}

# NAT gateway (any private subnets should not have access from outside of AWS)
# Going to create Elastic IP first
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_nat_gateway" "nat_gateway" {

  depends_on = [ aws_eip.nat_eip ]
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.asm4_public_subnets[0].id

  tags = {
    "Name" = "Private NAT GW: For goorm asm4"
  }
}

resource "aws_security_group" "asm4_sg" {
  name        = "asm4_sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.groomVPC.id

  ingress {
    description      = ""
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = ""
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "http_ssh_access"
  }
}

resource "aws_security_group" "rds-sg" {

  name = "rds-sg"
  vpc_id = aws_vpc.groomVPC.id

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.asm4_sg.id]
  }

  tags = {
    Name = "rds-sg"
  }
}

# load balancing
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.asm4_sg.id]
  subnets            = [aws_subnet.asm4_public_subnets[0].id, aws_subnet.asm4_public_subnets[1].id]

  enable_deletion_protection = false
}

# Target group that lb can listen to
resource "aws_lb_target_group" "web_lb" {

  name = "web-lb-tg"
  target_type = "instance"
  port = "80"
  protocol = "HTTP"
  vpc_id = aws_vpc.groomVPC.id

}

# Web lb listener
resource "aws_lb_listener" "web_lb_listener" {

  load_balancer_arn = aws_lb.web_lb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web_lb.arn
  }
}

# App load balancing
resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.asm4_sg.id]
  subnets            = [aws_subnet.asm4_private_subnets[0].id, aws_subnet.asm4_private_subnets[1].id]

  enable_deletion_protection = false
}

# Target group that lb can listen to
resource "aws_lb_target_group" "app_lb" {

  name = "app-lb-tg"
  target_type = "instance"
  port = "80"
  protocol = "HTTP"
  vpc_id = aws_vpc.groomVPC.id

}

# Web lb listener
resource "aws_lb_listener" "app_lb_listener" {

  load_balancer_arn = aws_lb.app_lb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app_lb.arn
  }
}

#creating key pair
resource "tls_private_key" "create_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name = var.key_name
  public_key = tls_private_key.create_key.public_key_openssh

  provisioner "local-exec" {    # Generate "terraform-key-pair.pem" in current directory
    command = <<-EOT
      echo '${tls_private_key.create_key.private_key_pem}' > ./'${var.key_name}'.pem
      chmod 400 ./'${var.key_name}'.pem
    EOT
  }
}

resource "local_file" "private_key" {
  content = tls_private_key.create_key.private_key_pem
  filename = var.key_name
}

# Creating Web EC2 instance
resource "aws_launch_template" "web" {
  name = "web"
  image_id = "ami-0f3a440bbcff3d043"
  instance_type = "t2.micro"

  key_name = aws_key_pair.key_pair.key_name

  network_interfaces {
    security_groups = [ aws_security_group.asm4_sg.id ]
    associate_public_ip_address = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {

      Name = "web"
    }
  }

}

# Creating App EC2 instance
resource "aws_launch_template" "app" {
  
  image_id = "ami-0f3a440bbcff3d043"
  instance_type = "t2.micro"

  key_name = aws_key_pair.key_pair.key_name

  network_interfaces {
    security_groups = [ aws_security_group.asm4_sg.id ]
    associate_public_ip_address = false
  }

  tag_specifications {
    resource_type = "instance"

    tags = {

      Name = "app"
    }
  }

}

# Auto Scaling Group - Web
resource "aws_autoscaling_group" "web_asg" {

  name = "web_asg"
  min_size = 2
  max_size = 2
  desired_capacity = 2
  target_group_arns = [ aws_lb_target_group.web_lb.arn ]
  vpc_zone_identifier = [ aws_subnet.asm4_public_subnets[0].id, aws_subnet.asm4_public_subnets[1].id ]

  launch_template {
    id = aws_launch_template.web.id
    version = "$Latest"
  }
}

# Auto Scaling Group - App
resource "aws_autoscaling_group" "app_asg" {

  name = "app_asg"
  min_size = 2
  max_size = 2
  desired_capacity = 2
  target_group_arns = [ aws_lb_target_group.app_lb.arn ]
  vpc_zone_identifier = [ aws_subnet.asm4_private_subnets[0].id, aws_subnet.asm4_private_subnets[1].id ]

  launch_template {
    id = aws_launch_template.app.id
    version = "$Latest"
  }
}

# Route table

# public
resource "aws_route_table" "web_public_route_table" {

  vpc_id = aws_vpc.groomVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_internet_gateway.id
  }

  tags = {
    Name = "RT public: For asm4 web"
  }
}


resource "aws_route_table_association" "web_rta_a" {

  subnet_id = aws_subnet.asm4_public_subnets[0].id
  route_table_id = aws_route_table.web_public_route_table.id
}

resource "aws_route_table_association" "web_rta_c" {

  subnet_id = aws_subnet.asm4_public_subnets[1].id
  route_table_id = aws_route_table.web_public_route_table.id
}

# app
resource "aws_route_table" "app_private_route_table" {

  vpc_id = aws_vpc.groomVPC.id

  tags = {
    Name = "RT private: For asm4 app"
  }
}

resource "aws_route_table_association" "app_rta_a" {

  subnet_id = aws_subnet.asm4_private_subnets[0].id
  route_table_id = aws_route_table.web_public_route_table.id
}

resource "aws_route_table_association" "app_rta_c" {

  subnet_id = aws_subnet.asm4_private_subnets[1].id
  route_table_id = aws_route_table.web_public_route_table.id
}

resource "aws_route" "db_private_route_table" {

  route_table_id = aws_route_table.app_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "rds_rta" {

  subnet_id = aws_subnet.asm4_db_private_subnets[0].id
  route_table_id = aws_route_table.app_private_route_table.id
}

# RDS
resource "aws_db_subnet_group" "rds_subnet_group" {

  name = "rds-subnet-group"
  subnet_ids = [ aws_subnet.asm4_db_private_subnets[0].id, aws_subnet.asm4_db_private_subnets[1].id]
}

resource "aws_db_parameter_group" "rds-pg" {

  name = "rds-pg"
  family = "postgres15"

  parameter {
    name = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "rds_instance_rw" {

  engine               = "postgres"
  instance_class       = "db.t3.micro"
  allocated_storage    = 5
  storage_type         = "gp2"
  username             = "root"
  password             = "password"
  publicly_accessible = false
  skip_final_snapshot  = true
  multi_az = true

  identifier = "rds-instance-rw"
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [ aws_security_group.rds-sg.id ]
  parameter_group_name = aws_db_parameter_group.rds-pg.name
  backup_retention_period = 1
  backup_window = "03:00-04:00"
}

# Replica - read only

resource "aws_db_instance" "rds_instance_ro" {

  instance_class       = "db.t3.micro"
  skip_final_snapshot  = true
  identifier = "rds-instance-ro"

  replicate_source_db = aws_db_instance.rds_instance_rw.identifier
  parameter_group_name = aws_db_parameter_group.rds-pg.name
  apply_immediately = true
  vpc_security_group_ids = [ aws_security_group.rds-sg.id ]
  multi_az = true
}

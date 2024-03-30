# configured aws provider with proper credentials
provider "aws" {
  region  = "us-east-1"
}


# create custom vpc if one does not exit
resource "aws_vpc" "custom_vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "custom_vpc"
    }
}


# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}


# create subnet if one does not exit
resource "aws_subnet" "custom_subnet" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available_zones.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "custom_subnet_1"
  }
}

# Additional subnet in different availability zone (required for ALB)
resource "aws_subnet" "custom_subnet_2" {
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available_zones.names[1] # Użyj innej strefy dostępności
  map_public_ip_on_launch = true

  tags = {
    Name = "custom_subnet_2"
  }
}

resource "aws_internet_gateway" "custom_igw" {
    vpc_id = aws_vpc.custom_vpc.id

    tags = {
        Name = "custom_igw"
    }
}

resource "aws_route_table" "custom_route_table" {
    vpc_id = aws_vpc.custom_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.custom_igw.id
    }

    tags = {
        Name = "custom_route_table"
    }
}

resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.custom_subnet.id
    route_table_id = aws_route_table.custom_route_table.id
}


resource "aws_security_group" "alb_security_group" {
  name        = "alb-security-group"
  description = "Security group for ALB allowing HTTP access"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ALB SG"
  }
}


# Define Application Load Balancer
resource "aws_lb" "frontend_lb" {
  name               = "frontend-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [aws_subnet.custom_subnet.id, aws_subnet.custom_subnet_2.id] # use both subnets
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.frontend_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

resource "aws_lb_target_group" "frontend_tg" {
  name     = "frontend-target-group"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.custom_vpc.id
}


# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 80, 22, 3000, and 8080"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow traffic on port 8080 for backend
  ingress {
    description = "backend access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "docker server sg"
  }
}

# Allow traffic from ALB to EC2 on port 3000
resource "aws_security_group_rule" "allow_from_alb" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  security_group_id = aws_security_group.ec2_security_group.id
  source_security_group_id = aws_security_group.alb_security_group.id
}


# use data source to get a registered amazon linux 2 ami
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


# launch the ec2 instance
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.custom_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "tic_tac_key"

  tags = {
    Name = "Tic-Tac-Toe"
  }
}


# an empty resource block
resource "null_resource" "name" {

  # ssh into the ec2 instance 
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("./tic_tac_key.pem")
    host        = aws_instance.ec2_instance.public_ip
  }

  # copy the password file for your docker hub account
  # from your computer to the ec2 instance 
  provisioner "file" {
   source      = "./docker_password.txt"
   destination = "/home/ec2-user/docker_password.txt"

  }


  # copy the deployment.sh from your computer to the ec2 instance 
  provisioner "file" {
    source      = "deployment.sh"
    destination = "/home/ec2-user/deployment.sh"
  }

  # set permissions and run the build_docker_image.sh file
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ec2-user/deployment.sh",
      "sh /home/ec2-user/deployment.sh",

    ]
  }

  # wait for ec2 to be created
  depends_on = [aws_instance.ec2_instance]

}
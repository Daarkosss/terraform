# configured aws provider with proper credentials
provider "aws" {
  region  = "us-east-1"
}


# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {

  tags = {
    Name = "default vpc"
  }
}


# use data source to get all avalablility zones in region - commented due to lack of permission
data "aws_availability_zones" "available_zones" {}


# create default subnet if one does not exit
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags = {
    Name = "default subnet"
  }
}


# create security group for the ec2 instance
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 80, 22, 3000, and 8080"
  vpc_id      = aws_default_vpc.default_vpc.id

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

  # Allow traffic on port 3000 for frontend
  ingress {
    description = "frontend access"
    from_port   = 3000
    to_port     = 3000
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


# use data source to get a registered amazon linux 2 ami - commented due to lack of permission
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
  subnet_id              = aws_default_subnet.default_az1.id
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "tic_tac_key"

  tags = {
    Name = "Tic-Tac-Toe-5"
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
  # copy the dockerfile from your computer to the ec2 instance 
  provisioner "file" {
    source      = "docker-compose.yml"
    destination = "/home/ec2-user/docker-compose.yml"
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

# print the url of the container
output "container_url" {
  value = join("", ["http://", aws_instance.ec2_instance.public_dns])
}
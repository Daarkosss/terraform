# Configure the AWS provider and region
provider "aws" {
  region = "us-east-1"  # Set the region where the resources will be created
}


# Create a custom VPC (Virtual Private Cloud) to place our instance on it
resource "aws_vpc" "custom_vpc" {
  cidr_block           = "10.0.0.0/16"  # Define the IP address range for the VPC (from 10.0.0.0 to 10.0.255.255)
  enable_dns_support   = true           # Enable DNS support within the VPC
  enable_dns_hostnames = true           # Enable DNS hostnames within the VPC

  tags = {
    Name = "custom_vpc"  # Set a name tag for the VPC
  }
}


# Fetch data about the available availability zones in the region
data "aws_availability_zones" "available_zones" {
  # No filters are applied, it fetches all availability zones
}


# Create a subnet within the custom VPC
resource "aws_subnet" "custom_subnet" {
  vpc_id            = aws_vpc.custom_vpc.id  # Associate the subnet with the custom VPC
  cidr_block        = "10.0.1.0/24"          # Define the IP address range for the subnet (from 10.0.1.0 to 10.0.1.255)
  availability_zone = data.aws_availability_zones.available_zones.names[0]  # Use the first available AZ
  map_public_ip_on_launch = true  # Automatically assign public IP to instances launched in this subnet

  tags = {
    Name = "custom_subnet"  # Set a name tag for the subnet
  }
}


# Create an Internet Gateway and attach it to the VPC, used to enable communication between resources in the VPC and the Internet
resource "aws_internet_gateway" "custom_igw" {
  vpc_id = aws_vpc.custom_vpc.id  # Associate the IGW with the custom VPC

  tags = {
    Name = "custom_igw"  # Set a name tag for the Internet Gateway
  }
}


# Create a route table for the VPC to define rules for traffic routing,
# determines how network traffic is routed between subnets in a VPC, as well as between the VPC and the Internet.
resource "aws_route_table" "custom_route_table" {
  vpc_id = aws_vpc.custom_vpc.id  # Associate the route table with the custom VPC

  route {
    cidr_block = "0.0.0.0/0"  # Define a default route (to route all traffic). All traffic directed to any address outside the VPC should be redirected to the Internet Gateway
    gateway_id = aws_internet_gateway.custom_igw.id  # Specify the IGW as the gateway
  }

  tags = {
    Name = "custom_route_table"  # Set a name tag for the Route Table
  }
}


# Associate the subnet with the route table to enable routing
resource "aws_route_table_association" "a" {
  subnet_id       = aws_subnet.custom_subnet.id
  route_table_id  = aws_route_table.custom_route_table.id
}


# Create a security group for the EC2 instance with specific rules
resource "aws_security_group" "ec2_security_group" {
  name        = "ec2 security group"
  description = "allow access on ports 80, 22 and 8080"
  vpc_id      = aws_vpc.custom_vpc.id  # Associate the security group with the custom VPC

  # Allow HTTP access on port 80 from anywhere
  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH access on port 22 from anywhere
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow backend access on port 8080 from anywhere
  ingress {
    description = "backend access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic from the instances
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "docker server sg"  # Set a name tag for the Security Group
  }
}


# Fetch data about the Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true  # Fetch the most recent AMI
  owners      = ["amazon"]  # Filter to only include AMIs owned by Amazon

  filter {
    name   = "owner-alias"
    values = ["amazon"] # The same as above, maybe not necessary
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]  # Filter to specific AMI naming pattern
  }
}


# Launch an EC2 instance with the specified settings
resource "aws_instance" "ec2_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id  # Use the fetched Amazon Linux 2 AMI
  instance_type          = "t2.micro"  # Specify the instance type
  subnet_id              = aws_subnet.custom_subnet.id  # Launch in the created subnet
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]  # Associate the security group
  key_name               = "tic_tac_key"  # Specify the key pair for SSH access

  tags = {
    Name = "Tic-Tac-Toe"  # Set a name tag for the EC2 instance
  }
}


# A null resource block to run necessary scripts on the EC2 instance
resource "null_resource" "name" {
  # SSH connection details for the EC2 instance
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("./tic_tac_key.pem")
    host        = aws_instance.ec2_instance.public_ip
  }

  # Copy the docker password file from local to the EC2 instance
  provisioner "file" {
    source      = "./docker_password.txt"
    destination = "/home/ec2-user/docker_password.txt"
  }

  # Copy the deployment script from local to the EC2 instance
  provisioner "file" {
    source      = "deployment.sh"
    destination = "/home/ec2-user/deployment.sh"
  }

  # Set permissions and execute the deployment script on the EC2 instance
  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ec2-user/deployment.sh",
      "sh /home/ec2-user/deployment.sh",
    ]
  }

  # Ensure this resource is created after the EC2 instance is available
  depends_on = [aws_instance.ec2_instance]
}

# Provider configuration
provider "aws" {
  region     = "us-east-1"
  access_key = "ASIAXGN2AYHMBGPMI7OI"
  secret_key = "65my+lMcljORJb906rRXaYY+sf6yJOuMu1+D9WTh"
  token      = "IQoJb3JpZ2luX2VjEEQaCXVzLXdlc3QtMiJHMEUCIQCkIrxFGhSHcizEmiphvqhWATinn3Hr0VWqrHC3KVo9uAIgR0U48VSdSKVv3kTuBeIYiVDNe5r1wNVW+sJGAkEUsdoqvQII3P//////////ARAAGgw0OTQ4NDgyMjk4NDgiDNMfjX4+h5lmerhJByqRAuokMzGLbcZrFhylWCnBWI1lmJf9xzuDdN6Q6dVNdF8ft3UODOrB3bOpS/GD4JKhXvivIfO8tAN36w5dC+bO3qNTNwAPh53lNpjFDLgv6KtRX/mIC8Umy2YfX1t0OX/XytU0UK/7T1C99Km2acLwM156H5DytA/jfCWAEobGO4FDa+bauOPl7osHK9ClydL4QoU9MhSXIJgcUXcOzLSOIqKSZ35NCN2YvXJxRg8cDvTmVJPf/EF1Wb61N0CH1qMiaEqyFDbhTZe5bQZLzXzn00k7NtwlJg68+vh5V43vT9VBtNHiNFzDuevSVuZulTScKX8hHsRhVqpiHd8NtjgGzyJZBf7rzImQqTkwEGOkX7yPRDCS1Yi6BjqdAY8wbIjCMT0W08iCY38zhjx33AorunJgeEF7a2ONKAfuV3hvJEdyibDrDAPDWp/7hFAr8a20Yp3WIPc3NoBNfjSKF1IRiYTVc+TLzbI7fZJodAYv5uyOCo/OuprtGP+K219HDbdlQ2zel0pStA+S4zNuFxN2TAr0b8W8WeOAZxJasAhMoOaeV5cRQ4oEOjHoFTgk2IyjwPPgVmAcCNE="
}

# VPC
resource "aws_vpc" "workshop_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Workshop_VPC"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "workshop_igw" {
  vpc_id = aws_vpc.workshop_vpc.id
  tags = {
    Name = "Workshop_Internet_Gateway"
  }
}

# Route Table
resource "aws_route_table" "workshop_route_table" {
  vpc_id = aws_vpc.workshop_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.workshop_igw.id
  }

  tags = {
    Name = "Workshop_Route_Table"
  }
}

# Subnet
resource "aws_subnet" "workshop_subnet" {
  vpc_id            = aws_vpc.workshop_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Workshop_Subnet"
  }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "workshop_route_table_assoc" {
  subnet_id      = aws_subnet.workshop_subnet.id
  route_table_id = aws_route_table.workshop_route_table.id
}

# Security Group
resource "aws_security_group" "workshop_sg" {
  vpc_id = aws_vpc.workshop_vpc.id

  # Allow HTTP access (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH access (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Workshop_Security_Group"
  }
}

# EC2 Instance
resource "aws_instance" "workshop_ec2" {
  count         = 2                       # Create 2 instances
  ami           = "ami-04505e74c0741db8d"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.workshop_subnet.id
  associate_public_ip_address = true
  key_name      = "vockey"

  # Security group
  vpc_security_group_ids = [aws_security_group.workshop_sg.id]

  # User data script to install Apache and set up a simple webpage
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2
              echo "<h1>Hello from instance ${count.index + 1}</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "Workshop_EC2_${count.index + 1}"
  }
}

# Load Balancer
resource "aws_elb" "workshop_elb" {
  name               = "workshop-elb"
  security_groups    = [aws_security_group.workshop_sg.id]
  subnets            = [aws_subnet.workshop_subnet.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "HTTP:80/"
  }

  # Attach instances to the Load Balancer
  instances = aws_instance.workshop_ec2[*].id

  tags = {
    Name = "Workshop_ELB"
  }
}

# Output the Load Balancer's DNS Address
output "load_balancer_dns" {
  value       = aws_elb.workshop_elb.dns_name
  description = "The DNS name of the Load Balancer."
}

# Output the public IP addresses of the instances
output "instance_ips" {
  value       = aws_instance.workshop_ec2[*].public_ip
  description = "The public IP addresses of the EC2 instances."
}
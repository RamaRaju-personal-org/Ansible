provider "aws" {
  region = "us-east-1"
}

variable vpc_cidr_block {}
variable subnet_1_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable instance_type {}
variable ssh_key_public {}
variable my_ip {}
variable ssh_key_private {}

data "aws_ami" "amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "ami_id" {
  value = data.aws_ami.amazon-linux-image.id
}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true // plublic dns
  tags = {
      Name = "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_1_cidr_block
  availability_zone = var.avail_zone
  tags = {
      Name = "${var.env_prefix}-subnet-1"
  }
}

resource "aws_security_group" "myapp-sg" { // allow only my ip to ssh
  name   = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.env_prefix}-sg"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
	vpc_id = aws_vpc.myapp-vpc.id
    
    tags = {
     Name = "${var.env_prefix}-internet-gateway"
   }
}

resource "aws_route_table" "myapp-route-table" {
   vpc_id = aws_vpc.myapp-vpc.id

   route {
     cidr_block = "0.0.0.0/0"
     gateway_id = aws_internet_gateway.myapp-igw.id
   }

   # default route, mapping VPC CIDR block to "local", created implicitly and cannot be specified.

   tags = {
     Name = "${var.env_prefix}-route-table-test"
   }
 }

# Associate subnet with Route Table
resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id      = aws_subnet.myapp-subnet-1.id
  route_table_id = aws_route_table.myapp-route-table.id
}


// generate your own keys and aws_key_pair will upload it to aws
// ssh-keygen -t rsa -b 2048 -f /Users/path/location/key_name

resource "aws_key_pair" "ssh-key" {
  key_name   = "ansible_key"
  public_key = file(var.ssh_key_public)
}

output "server-ip" {
    value = aws_instance.myapp-server-ansible.public_ip
}

# resource "aws_instance" "myapp-server" {
#   ami                         = data.aws_ami.amazon-linux-image.id
#   instance_type               = var.instance_type
#   key_name                    = "myapp-key"
#   associate_public_ip_address = true
#   subnet_id                   = aws_subnet.myapp-subnet-1.id
#   vpc_security_group_ids      = [aws_security_group.myapp-sg.id]
#   availability_zone			      = var.avail_zone

#   tags = {
#     Name = "${var.env_prefix}-server"
#   }
# }


resource "aws_instance" "myapp-server-ansible" {
  ami                         = data.aws_ami.amazon-linux-image.id
  instance_type               = var.instance_type
  key_name                    = "ansible_key"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids      = [aws_security_group.myapp-sg.id]
  availability_zone			      = var.avail_zone

  tags = {
    Name = "${var.env_prefix}-server"
  }
  
  #  provisioner "local-exec" {
  #   command = "sleep 15"
  # }

  #  provisioner "remote-exec" {
  #   inline = [
  #     "sudo yum update -y",
  #     "sudo yum install -y python3"
  #   ]

  #   connection {
  #     type        = "ssh"
  #     user        = "ec2-user"
  #     private_key = file(var.ssh_key_private)
  #     host        = self.public_ip
  #   }
  # }
  
   
  
  #  provisioner "local-exec" {
  #   working_dir = "/Users/ramraju/Desktop/Ansible"
  #   command = "ansible-playbook --inventory ${aws_instance.myapp-server-ansible.public_ip}, --private-key ${var.ssh_key_private} --user ec2-user deploy-docker-with-roles.yaml"
  # }

  
}

/* to execute it separetly 
resource "null_resource" "configure_server" {
  triggers = {
    trigger = aws_instance.myapp-server.public_ip
  }

  provisioner "local-exec" {
    working_dir = "../ansible"
    command = "ansible-playbook --inventory ${aws_instance.myapp-server.public_ip}, --private-key ${var.ssh_key_private} --user ec2-user deploy-docker-new-user.yaml"
  }
}
*/

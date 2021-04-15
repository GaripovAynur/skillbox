provider "aws" {
  access_key = "AKIAUOABTBSCSUJSRPWJ"
  secret_key = "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"
  region     = "us-east-2"
}


resource "aws_eip" "my_static_ip" {
  instance = aws_instance.my_webserver.id
  tags = {
    Name  = "ReactJS Server IP for Ansible"
  }
}

# Ищем образ с последней версией Ubuntu
data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
 }
}

# Запускаем инстанс
resource "aws_instance" "my_webserver" {
  # с выбранным образом 
  ami                    = data.aws_ami.ubuntu.id
  # и размером (количество ЦПУ и памяти зависит от этой директивы) 
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_webserver.id]
  user_data = file("user_data.sh")
  #key_name = "id_rsa"
  tags = {
   #AMI =  "${data.aws_ami.ubuntu.id}"
    Name  = "ReactJS Server IP"
    Env = "Production"
    Tier = "Frontend"
    CM = "Ansible"
  }

  lifecycle {
    create_before_destroy = true
  }

}


resource "aws_security_group" "my_webserver" {
  name        = "ReactJS Servers Security Group for Ansible"
  description = "Security group for accessing traffic to our ReactJS Server for Ansible"


  dynamic "ingress" {
    for_each = ["80", "22", "81"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "ReactJS Server SecurityGroup for Ansible"
  }
}

# Выведем IP адрес сервера
output "my_web_site_ip" {
  description = "Elatic IP address assigned to our WebSite"
  value       = aws_eip.my_static_ip.public_ip
}

# Указываем, что мы хотим разворачивать окружение в AWS
provider "aws" {
  access_key = "AKIAUOABTBSCTTHETNSA"
  secret_key = "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"
  region     = "us-east-2"

}


# Узнаём, какие есть Дата центры в выбранном регионе
data "aws_availability_zones" "available" {}

# Ищем образ с последней версией Ubuntu
data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Созаём правило, которое будет разрешать трафик к нашим серверам
resource "aws_security_group" "web" {
  name = "Dynamic Security Group"

  dynamic "ingress" {
    # Зададим правило, по каким портам можно обращаться к нашим серверам
    for_each = ["22", "80"]
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
    Name = "Web access for Application"
  }
}


# Создаём Launch Configuration - это сущность, которая определяет конфигурацию запускаемых серверов. Размер, ,

resource "aws_launch_configuration" "web" {
  name_prefix = "NGINX-"
  # какой будет использоваться образ
  image_id = data.aws_ami.ubuntu.id
  # Размер машины (CPU и память)
  instance_type = "t2.micro"
  # какие права доступа
  security_groups = [aws_security_group.web.id]
  # какие следует запустить скрипты при создании сервера
  user_data = file("user_data.sh")
  # какой SSH ключ будет использоваться
  key_name = "lesson1"
  # Если мы решим обновить инстанс, то, прежде, чем удалится старый инстанс, который больше не нужен, должен запуститься новый
  lifecycle {
    create_before_destroy = true
  }
}


# AWS Autoscaling Group для указания, сколько нам понадобится инстансов
resource "aws_autoscaling_group" "web" {
  name                 = "ASG-${aws_launch_configuration.web.name}"
  launch_configuration = aws_launch_configuration.web.name
  min_size             = 2
  max_size             = 2
  min_elb_capacity     = 2
  health_check_type    = "ELB"
  # и в каких подсетях, каких Дата центрах их следует разместить
  vpc_zone_identifier = [aws_default_subnet.availability_zone_1.id, aws_default_subnet.availability_zone_2.id]
  # Ссылка на балансировщик нагрузки, который следует использовать
  load_balancers = [aws_elb.web.name]

  dynamic "tag" {
    for_each = {
      Name = "Nginx Server in Auto Scalling Group"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic Load Balancer проксирует трафик на наши сервера
resource "aws_elb" "web" {
  name = "Nginx-Highly-Available-ELB"
  # перенаправляет трафик на несколько Дата центров
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  security_groups    = [aws_security_group.web.id]
  # слушает на порту 80
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold   = 9
    unhealthy_threshold = 10
    timeout             = 60
    target              = "HTTP:80/"
    interval            = 300
  }
  tags = {
    Name = "Nginx-Highly-Available-ELB"
  }
}

# Созаём подсети в разных Дата центрах
resource "aws_default_subnet" "availability_zone_1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_default_subnet" "availability_zone_2" {
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_eip" "my_static_ip" {
  instance = aws_instance.my_webserver.id
  tags = {
    Name = "ReactJS Server IP for Ansible"
  }
}


# Запускаем инстанс
resource "aws_instance" "my_webserver" {
  # с выбранным образом
  ami = data.aws_ami.ubuntu.id
  # и размером (количество ЦПУ и памяти зависит от этой директивы)
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name = "lesson1"
  tags = {
    Name = "ReactJS Server"
    Env  = "Production"
    Tier = "Backend"
    CM   = "Ansible"
  }

  lifecycle {
    create_before_destroy = true
  }

}

# Выведем в консоль DNS имя нашего сервера
output "web_loadbalancer_url" {
  value = aws_elb.web.dns_name
}

# Выведем IP адрес сервера
output "my_web_site_ip" {
  description = "Elatic IP address assigned to our ReactJS Server"
  value       = aws_eip.my_static_ip.public_ip
}

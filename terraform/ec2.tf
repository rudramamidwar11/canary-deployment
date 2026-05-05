resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Canary deployment EC2"
ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "HTTP"
}
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "SSH"
}
ingress {
  from_port   = 9090
  to_port     = 9090
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Prometheus"
}

ingress {
  from_port   = 3000
  to_port     = 3000
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Grafana"
}

egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file("C:/Users/ASUS/.ssh/canary-deploy.pub")
}

resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  root_block_device {
  volume_size = 20
  volume_type = "gp2"
}

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    ecr_repo_url = aws_ecr_repository.app.repository_url
    aws_region   = var.aws_region
    project_name = var.project_name
  }))

  tags = { Name = "${var.project_name}-server", Project = var.project_name }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
}
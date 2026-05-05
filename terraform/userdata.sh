#!/bin/bash
set -e
yum update -y
yum install -y docker nginx python3 python3-pip amazon-ssm-agent

systemctl start docker && systemctl enable docker
systemctl start amazon-ssm-agent && systemctl enable amazon-ssm-agent
usermod -aG docker ec2-user

pip3 install boto3 requests

# Docker Compose
curl -sL "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

# Node Exporter
useradd --no-create-home --shell /bin/false node_exporter || true
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xf node_exporter-1.7.0.linux-amd64.tar.gz
cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.7.0.linux-amd64*

cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
After=network.target
[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl start node_exporter && systemctl enable node_exporter

mkdir -p /home/ec2-user/{scripts,config,logs}

# Store env vars
cat >> /home/ec2-user/.bashrc << EOF
export ECR_REPO_URL=${ecr_repo_url}
export AWS_REGION=${aws_region}
export PROJECT_NAME=${project_name}
EOF

chown -R ec2-user:ec2-user /home/ec2-user
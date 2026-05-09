#!/bin/bash
set -e
source /home/ec2-user/.bashrc

mkdir -p /home/ec2-user/{scripts,config,logs}

# Copy nginx configs
aws s3 cp s3://${PROJECT_NAME}-artifacts-$(aws sts get-caller-identity --query Account --output text)/nginx/ \
  /home/ec2-user/config/ --recursive

# Copy prometheus configs
aws s3 cp s3://${PROJECT_NAME}-artifacts-$(aws sts get-caller-identity --query Account --output text)/prometheus/ \
  /home/ec2-user/config/ --recursive

# Apply stable nginx config to start
sudo cp /home/ec2-user/config/nginx-stable.conf /etc/nginx/conf.d/app.conf
sudo nginx -t && sudo systemctl reload nginx

# Start monitoring stack
cd /home/ec2-user
docker-compose -f /home/ec2-user/config/docker-compose.yml up -d

# Pull and run stable image
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REPO_URL

docker run -d \
  --name app-stable \
  --restart unless-stopped \
  -p 5001:5000 \
  -e APP_VERSION=v1 \
  -e SIMULATE_ERRORS=false \
  ${ECR_REPO_URL}:stable

# Cron: push Prometheus metrics to CloudWatch every minute
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/python3 /home/ec2-user/scripts/push-metrics.py >> /home/ec2-user/logs/metrics.log 2>&1") | crontab -

echo "Setup complete!"
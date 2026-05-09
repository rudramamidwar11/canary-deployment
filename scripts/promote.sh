#!/bin/bash
set -e
source /home/ec2-user/.bashrc

echo "=== Promoting canary to stable ==="

# Stop old stable, restart using canary image on port 5001
docker stop app-stable 2>/dev/null || true
docker rm   app-stable 2>/dev/null || true

docker run -d \
  --name app-stable \
  --restart unless-stopped \
  -p 5001:5000 \
  -e APP_VERSION=v2 \
  -e SIMULATE_ERRORS=false \
  ${ECR_REPO_URL}:canary

# Stop canary container
docker stop app-canary 2>/dev/null || true
docker rm   app-canary 2>/dev/null || true

# Shift nginx to 100% stable
sudo cp /home/ec2-user/config/nginx-stable.conf /etc/nginx/conf.d/app.conf
sudo nginx -t && sudo systemctl reload nginx

# Tag canary image as stable and push
docker tag ${ECR_REPO_URL}:canary ${ECR_REPO_URL}:stable
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REPO_URL
docker push ${ECR_REPO_URL}:stable

echo "=== Promotion complete! 100% traffic on v2 ==="
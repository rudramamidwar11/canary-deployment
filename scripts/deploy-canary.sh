#!/bin/bash
set -e
source /home/ec2-user/.bashrc

echo "=== Canary Deploy Start ==="

# ECR login
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REPO_URL

# Pull latest canary image
docker pull ${ECR_REPO_URL}:canary

# Remove old canary if exists
docker stop app-canary 2>/dev/null || true
docker rm   app-canary 2>/dev/null || true

# Run canary on port 5002 WITH simulated errors (for demo)
docker run -d \
  --name app-canary \
  --restart unless-stopped \
  -p 5002:5000 \
  -e APP_VERSION=v2 \
  -e SIMULATE_ERRORS=true \
  ${ECR_REPO_URL}:canary

# Wait and verify health
sleep 5
for i in 1 2 3 4 5; do
  if curl -sf http://localhost:5002/health > /dev/null; then
    echo "Canary healthy!"
    break
  fi
  echo "Attempt $i/5..."
  sleep 3
  [ $i -eq 5 ] && { echo "Canary unhealthy!"; docker rm -f app-canary; exit 1; }
done

# Switch nginx to canary routing (10% to v2)
sudo cp /home/ec2-user/config/nginx-canary.conf /etc/nginx/conf.d/app.conf
sudo nginx -t && sudo systemctl reload nginx

echo "=== Canary live: 10% traffic → v2 (5002), 90% → v1 (5001) ==="
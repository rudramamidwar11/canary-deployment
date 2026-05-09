#!/bin/bash
set -e
source /home/ec2-user/.bashrc

echo "=== ROLLBACK at $(date) ==="

# Ensure stable is running on port 5001
if ! docker inspect app-stable > /dev/null 2>&1; then
  echo "Starting stable container..."
  aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_REPO_URL
  docker run -d \
    --name app-stable \
    --restart unless-stopped \
    -p 5001:5000 \
    -e APP_VERSION=v1 \
    -e SIMULATE_ERRORS=false \
    ${ECR_REPO_URL}:stable
fi

# Kill canary
docker stop app-canary 2>/dev/null || echo "Canary already stopped"
docker rm   app-canary 2>/dev/null || true

# Restore 100% traffic to stable
sudo cp /home/ec2-user/config/nginx-stable.conf /etc/nginx/conf.d/app.conf
sudo nginx -t && sudo systemctl reload nginx

sleep 3
curl -sf http://localhost:5001/health && echo "Stable healthy!" || { echo "STABLE UNHEALTHY!"; exit 1; }

echo "=== ROLLBACK COMPLETE — 100% on v1 ==="
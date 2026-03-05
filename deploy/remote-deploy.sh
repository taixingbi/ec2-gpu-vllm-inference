#!/bin/bash
# Deploy script run via SSM on EC2. Expects HF_TOKEN env var (optional).
# Run from /home/ubuntu/deploy after files are downloaded from S3.
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-/home/ubuntu/deploy}"
if ! command -v docker >/dev/null 2>&1; then NEED_APT=true; fi
if [ "$NEED_APT" = true ]; then
  echo "=== Install Docker ==="
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo usermod -aG docker ubuntu || true
fi

if ! sudo docker info 2>/dev/null | grep -q "Runtimes:.*nvidia"; then
  echo "=== Install NVIDIA Container Toolkit ==="
  [ "$NEED_APT" != true ] && sudo apt-get update -y
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  sudo apt-get update -y
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
fi

echo "=== Free disk space before pull ==="
sudo apt-get clean 2>/dev/null || true
sudo journalctl --vacuum-time=1h 2>/dev/null || true
sudo docker system prune -af 2>/dev/null || true

echo "=== Prepare deploy directory ==="
sudo mkdir -p /opt/models
cd "$DEPLOY_DIR" || { echo "ERROR: $DEPLOY_DIR not found"; exit 1; }
if [ ! -f .env ]; then
  cp .env.example .env
fi
if [ -n "${HF_TOKEN:-}" ]; then
  sed -i '/^HUGGING_FACE_HUB_TOKEN=/d' .env
  printf 'HUGGING_FACE_HUB_TOKEN=%s\n' "$HF_TOKEN" >> .env
fi

echo "=== Deploy vLLM containers ==="
sudo docker compose pull
sudo docker compose up -d

echo "=== Waiting for vLLM (models may take 5-15 min to load) ==="
sudo docker ps -a
for i in $(seq 1 180); do
  if curl -sf http://127.0.0.1:8000/v1/models >/dev/null 2>&1; then
    echo "vLLM ready"
    break
  fi
  if [ $((i % 12)) -eq 0 ]; then
    echo "Still waiting... $((i*5))s"
    sudo docker ps -a --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || true
  fi
  if [ $i -eq 180 ]; then
    echo "Timeout (15 min). Container status:"
    sudo docker ps -a
    sudo docker logs vllm_infer --tail 50 2>&1 || true
    exit 1
  fi
  sleep 5
done

echo "=== Done ==="
sudo docker logs vllm_infer --tail 5 2>&1 || true

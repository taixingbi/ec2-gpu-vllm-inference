# EC2 GPU vLLM

Deploys vLLM (inference + embeddings) to a GPU EC2 instance via GitHub Actions.

## Architecture

- **Port 8000**: vLLM inference (`/v1/chat/completions`, `/v1/completions`)
- **Port 8001**: vLLM embeddings (`/v1/embeddings`)
- **Instance**: g5.xlarge (1× A10G 24GB)
- **Elastic IP**: Stable endpoint (no IP change on instance restart)

## Quick test from Mac

**Inference:**
```bash
curl http://EC2_IP:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "messages": [{"role":"user","content":"hello"}]
  }'
```

**Embeddings (OpenAI-compatible):**
```bash
curl http://EC2_IP:8001/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "BAAI/bge-small-en-v1.5",
    "input": ["AWS vLLM embedding test"]
  }'
```

Replace `EC2_IP` with your instance's Elastic IP (output by the deploy workflow).

## Repository configuration

### Required variables

| Variable | Description |
|----------|-------------|
| `AWS_AMI_ID` | GPU Deep Learning AMI (Ubuntu) for your region. Find at [AWS DLAMI](https://aws.amazon.com/machine-learning/amis/) |
| `AWS_SECURITY_GROUP_ID` | Security group with inbound: 22 (SSH), 8000, 8001 |
| `EC2_KEY_PAIR` | SSH key pair name (default: `ec2`) |

### Required secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS credentials |
| `EC2_SSH_KEY` | Private key for `ubuntu` user |

### Optional secrets

| Secret | Description |
|--------|-------------|
| `HUGGING_FACE_HUB_TOKEN` | For gated models (e.g. Llama) |

## Docker (local / manual)

**Prerequisites:** Docker with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) (requires an NVIDIA GPU).

```bash
cd deploy
cp .env.example .env
# Edit .env if needed (models, HUGGING_FACE_HUB_TOKEN)

docker compose pull
docker compose up -d
```

**Start:** `docker compose up -d`  
**Stop:** `docker compose down`  
**Logs:** `docker compose logs -f` (or `docker logs vllm_infer -f` / `docker logs vllm_embed -f`)

Models are cached in `/opt/models` on the host (or `~/.cache/huggingface` if you change the volume mount).

## Deploy

Push to `qa` or run the workflow manually. The workflow will:

1. Create a g5.xlarge instance (or reuse existing)
2. Allocate/associate an Elastic IP
3. Install Docker + NVIDIA Container Toolkit
4. Run two vLLM containers (inference + embeddings)

## Model configuration

Edit `deploy/.env.example` in the repo to change models before deploying. Defaults:

- **Inference**: `Qwen/Qwen2.5-7B-Instruct`
- **Embeddings**: `BAAI/bge-small-en-v1.5`

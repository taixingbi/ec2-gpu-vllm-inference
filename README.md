# EC2 GPU vLLM

Deploys vLLM (inference) to a GPU EC2 instance via GitHub Actions.

## Architecture

- **Port 8000**: vLLM inference (`/v1/chat/completions`, `/v1/completions`)
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

Replace `EC2_IP` with your instance's Elastic IP (output by the deploy workflow).

## Repository configuration

### Required variables

| Variable | Description |
|----------|-------------|
| `AWS_AMI_ID` | GPU Deep Learning AMI (Ubuntu) for your region. Optional: workflow auto-resolves if unset. [AWS DLAMI](https://aws.amazon.com/machine-learning/amis/) |
| `AWS_REGION` | AWS region (default: `us-east-1`) |
| `AWS_SECURITY_GROUP_ID` | Security group with inbound: 22 (SSH), 8000 |
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
# Edit .env if needed (INFER_MODEL, VLLM_IMAGE, VLLM_USE_NGC, HUGGING_FACE_HUB_TOKEN)

docker compose pull
docker compose up -d
```

**Start:** `docker compose up -d`  
**Stop:** `docker compose down`  
**Logs:** `docker compose logs -f` (or `docker logs vllm_infer -f`)

Models are cached in `/opt/models` on the host (or `~/.cache/huggingface` if you change the volume mount).

## Deploy

**Trigger:** Push to `qa` or run the workflow manually (Actions → Deploy vLLM → Run workflow; choose `prod` or `qa`).

The workflow will:

1. Create a g5.xlarge instance (or reuse existing)
2. Allocate/associate an Elastic IP
3. Install Docker + NVIDIA Container Toolkit
4. Run vLLM inference container (restarts on crash/reboot)

## Model configuration

Edit `deploy/.env.example` in the repo before deploying:

| Variable | Description |
|----------|-------------|
| `INFER_MODEL` | Model to serve (default: `Qwen/Qwen2.5-7B-Instruct`) |
| `VLLM_IMAGE` | Docker image (default: `vllm/vllm-openai:cu130-nightly`). Use `nvcr.io/nvidia/pytorch:25.01-py3` for NGC + pip install |
| `VLLM_USE_NGC` | Set to `1` when using NGC image (runs `pip install vllm` on startup) |

**Troubleshooting:** If you hit driver 803 or numpy/flash-attn errors, switch to NGC mode: set `VLLM_IMAGE=nvcr.io/nvidia/pytorch:25.01-py3` and `VLLM_USE_NGC=1` in `deploy/.env`.


## analysis test

ssh -i "ec2.pem" ubuntu@ec2-100-48-29-5.compute-1.amazonaws.com
curl -sSf http://127.0.0.1:8000/v1/models | head
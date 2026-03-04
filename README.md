# EC2 GPU vLLM

Deploy vLLM inference to a g5.xlarge GPU EC2 via GitHub Actions.

## Architecture

- **Port 8000**: vLLM (`/v1/chat/completions`, `/v1/completions`)
- **Instance**: g5.xlarge (1× A10G 24GB)
- **Elastic IP**: Stable endpoint

## Quick test

```bash
curl http://EC2_IP:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen2.5-7B-Instruct","messages":[{"role":"user","content":"hello"}]}'
```

Replace `EC2_IP` with the Elastic IP from the deploy workflow output.

## Configuration

### Repo variables

| Variable | Description |
|---------|-------------|
| `AWS_AMI_ID` | GPU AMI (optional; auto-resolved if unset) |
| `AWS_REGION` | Region (default: `us-east-1`) |
| `AWS_SECURITY_GROUP_ID` | SG with inbound 22, 8000 |
| `EC2_KEY_PAIR` | SSH key name (default: `ec2`) |

### Repo secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | AWS credentials |
| `EC2_SSH_KEY` | Private key for `ubuntu` |
| `HUGGING_FACE_HUB_TOKEN` | Optional; for gated models |

### Model (deploy/.env)

| Variable | Description |
|----------|-------------|
| `INFER_MODEL` | Model to serve (default: `Qwen/Qwen2.5-7B-Instruct`) |
| `VLLM_IMAGE` | Image (default: `vllm/vllm-openai:cu130-nightly`) |
| `VLLM_USE_NGC` | Set to `1` for NGC image + pip install vllm |

**Driver issues:** If you see 803 or numpy/flash-attn errors, use `VLLM_IMAGE=nvcr.io/nvidia/pytorch:25.01-py3` and `VLLM_USE_NGC=1`.

## Docker (local)

Requires [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).

```bash
cd deploy && cp .env.example .env
docker compose up -d
```

Models cached in `/opt/models`.

## Deploy

Push to `qa` or run the workflow manually. Steps: create/reuse g5.xlarge → attach EIP → install Docker + NVIDIA → run vLLM.

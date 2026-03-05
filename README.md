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

Uses **SSM + S3** deployment (no SSH required). The EC2 instance needs an IAM role with SSM and S3 access.

### Repo variables

| Variable | Description |
|---------|-------------|
| `AWS_REGION` | Region (default: `us-east-1`) |
| `AWS_AMI_ID` | GPU AMI (optional; auto-resolved if unset) |
| `AWS_SECURITY_GROUP_ID` | SG ID (e.g. `sg-xxxxx`); or use `AWS_SECURITY_GROUP_NAME` |
| `AWS_SECURITY_GROUP_NAME` | SG name to resolve if ID not set (default: `ec2`) |
| `EC2_KEY_PAIR` | EC2 key pair name (default: `ec2`) |
| `EC2_IAM_INSTANCE_PROFILE` | IAM instance profile for SSM (required, e.g. `ec2-ssm-role`) |
| `DEPLOY_BUCKET` | S3 bucket for deploy artifacts (required) |

### Repo secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | AWS credentials |
| `HUGGING_FACE_HUB_TOKEN` | Optional; for gated models |

**Note:** `EC2_SSH_KEY` is not needed for SSM + S3 deployment. You can remove it if migrating from SSH-based deploy.

### IAM requirements

The `EC2_IAM_INSTANCE_PROFILE` role must include:

- **AmazonSSMManagedInstanceCore** (for SSM Run Command)
- **s3:GetObject** on `arn:aws:s3:::DEPLOY_BUCKET/deploy/*`

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

Push to `qa` or run the workflow manually. Steps: create/reuse g5.xlarge (with SSM IAM profile) → attach EIP → upload deploy files to S3 → run deploy via SSM on instance → install Docker + NVIDIA → run vLLM.

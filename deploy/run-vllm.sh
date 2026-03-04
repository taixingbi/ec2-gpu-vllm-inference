#!/bin/bash
set -e
if [ "${VLLM_USE_NGC}" = "1" ] || [ "${VLLM_USE_NGC}" = "true" ]; then
  echo "NGC mode: installing vllm..."
  pip install -U vllm
fi
exec vllm serve "$@"

#!/bin/bash
set -e

# Retry until kubeconfig exists in SSM
i=0
while [ $i -lt 42 ]; do
  VAL=$(aws ssm get-parameter \
    --name "/k8s/kubeconfig" \
    --region us-east-1 \
    --query "Parameter.Value" \
    --output text 2>/dev/null || true)

  if [ "$VAL" != "" ] && [ "$VAL" != "None" ]; then
    echo "{\"kubeconfig\": \"$VAL\"}"
    exit 0
  fi

  echo "Still waiting for kubeconfig... ($i/42)" >&2
  sleep 10
  i=$((i+1))
done

echo "{\"kubeconfig\": \"\"}"
exit 1

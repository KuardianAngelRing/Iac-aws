#!/usr/bin/env bash
# EC2 초기화 스크립트 — Terraform user_data로 자동 실행
# 완료 시 /var/log/user_data_done 파일 생성 → up.sh이 폴링으로 감지

set -euo pipefail
exec > /var/log/user_data.log 2>&1

echo "[1/7] 시스템 업데이트..."
dnf update -y
dnf install -y --allowerasing git curl tar unzip jq

echo "[2/7] Node.js 20 설치..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

echo "[3/7] Python 3.11 설치..."
dnf install -y python3.11 python3.11-pip
alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 1

echo "[4/7] kubectl 설치..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin/

echo "[5/7] Helm 설치..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[6/7] 레포 클론..."
cd /home/ec2-user

git clone ${iac_aws_repo} Iac-aws || {
  echo "WARNING: Iac-aws 클론 실패 — private 레포라면 SSH key 설정 필요"
}

git clone ${iac_nextjs_repo} iac-nextjs || {
  echo "WARNING: iac-nextjs 클론 실패 — private 레포라면 SSH key 설정 필요"
}

echo "[7/7] .env 파일 생성..."

mkdir -p /home/ec2-user/.kube

# worker/.env
cat > /home/ec2-user/Iac-aws/worker/.env << 'ENVEOF'
SUPABASE_URL=${supabase_url}
SUPABASE_KEY=${supabase_key}
ANTHROPIC_API_KEY=${anthropic_key}
KUBECONFIG=/home/ec2-user/.kube/config
NEXTJS_API_URL=http://localhost:3000
PROMETHEUS_URL=http://localhost:9090
LOKI_URL=http://localhost:3100
IAC_AWS_PATH=/home/ec2-user/Iac-aws
ENVEOF

# iac-nextjs/.env.local
cat > /home/ec2-user/iac-nextjs/.env.local << 'ENVEOF'
NEXT_PUBLIC_SUPABASE_URL=${supabase_url}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${supabase_key}
PROMETHEUS_URL=http://localhost:9090
LOKI_URL=http://localhost:3100
ENVEOF

# Python 의존성 (requirements.txt는 Phase 3에서 생성됨)
[ -f /home/ec2-user/Iac-aws/worker/requirements.txt ] && \
  pip3 install -r /home/ec2-user/Iac-aws/worker/requirements.txt || true

# Next.js 빌드 — 성공 여부를 sentinel 파일로 분리
cd /home/ec2-user/iac-nextjs
npm install
if npm run build; then
  touch /var/log/nextjs_build_done
else
  echo "WARNING: Next.js 빌드 실패 — Phase 2 완료 후 EC2에서 수동 재빌드 필요"
fi

# 권한 정리
chown -R ec2-user:ec2-user /home/ec2-user/

# kubectl 자동 완성 + kubeconfig 경로
echo "export KUBECONFIG=/home/ec2-user/.kube/config" >> /home/ec2-user/.bashrc
echo "source <(kubectl completion bash)" >> /home/ec2-user/.bashrc

echo "user_data 완료!"
touch /var/log/user_data_done

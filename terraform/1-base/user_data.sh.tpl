#!/usr/bin/env bash
# EC2 초기화 스크립트 — Terraform user_data로 자동 실행
# Phase 1 전용: kubectl 거점 EC2 셋업만 수행 (Next.js / worker는 Phase 2/3에서 추가)
# 완료 시 /var/log/user_data_done 파일 생성 → up.sh이 폴링으로 감지

set -euo pipefail
exec > /var/log/user_data.log 2>&1

echo "[1/5] 시스템 업데이트..."
dnf update -y
dnf install -y --allowerasing git curl tar unzip jq

echo "[2/5] kubectl 설치..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/local/bin/

echo "[3/5] Helm 설치..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[4/5] Iac-aws 레포 클론..."
cd /home/ec2-user
git clone ${iac_aws_repo} Iac-aws || {
  echo "WARNING: Iac-aws 클론 실패 — private 레포라면 SSH key 설정 필요"
}

echo "[5/5] 디렉토리 / kubeconfig 준비..."
mkdir -p /home/ec2-user/.kube
chown -R ec2-user:ec2-user /home/ec2-user/

# kubectl 자동 완성 + kubeconfig 경로
echo "export KUBECONFIG=/home/ec2-user/.kube/config" >> /home/ec2-user/.bashrc
echo "source <(kubectl completion bash)" >> /home/ec2-user/.bashrc

echo "user_data 완료!"
touch /var/log/user_data_done

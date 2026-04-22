#!/usr/bin/env bash
# EKS 전체 구축 스크립트
# 실행 시간: 약 20~25분 (EKS 생성 15분 + 플랫폼 설치 10분)

set -euo pipefail

CLUSTER_NAME="chaos-eks"
AWS_REGION="ap-northeast-2"
KEY_PATH="$HOME/.ssh/chaos-eks-key.pem"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Terraform 자동화 환경 힌트 제거 + 전체 로그 파일 보존
export TF_IN_AUTOMATION=true
LOG_FILE="/tmp/iac-up-$(date +%Y%m%d-%H%M%S).log"
echo "📝 전체 로그: $LOG_FILE"

# ── 사전 확인 ──────────────────────────────────────────────────
echo "=== 사전 확인 ==="

for cmd in terraform aws kubectl helm ssh scp; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ '$cmd' 명령어를 찾을 수 없습니다. 설치 후 재실행하세요."
    exit 1
  fi
done

if [ ! -f "$KEY_PATH" ]; then
  echo "❌ Key Pair 없음: $KEY_PATH"
  echo "   ~/.ssh/chaos-eks-key.pem 경로에 Key Pair 파일을 놓으세요."
  exit 1
fi

if [ ! -f "$SCRIPT_DIR/../terraform/1-base/terraform.tfvars" ]; then
  echo "❌ terraform.tfvars 없음"
  echo "   terraform/1-base/terraform.tfvars 파일을 생성하세요."
  exit 1
fi

chmod 400 "$KEY_PATH"

# ── Phase 1: 인프라 구축 ────────────────────────────────────────
echo ""
echo "=== [1/5] 인프라 구축 (VPC + EKS + EC2) ==="
cd "$SCRIPT_DIR/../terraform/1-base"
terraform init -input=false 2>&1 | tee -a "$LOG_FILE"
terraform apply -auto-approve -compact-warnings -input=false 2>&1 | tee -a "$LOG_FILE"

EC2_IP=$(terraform output -raw ec2_public_ip)
echo "✅ EC2 IP: $EC2_IP"

# ── kubeconfig 로컬 설정 ────────────────────────────────────────
echo ""
echo "=== [2/5] kubeconfig 설정 ==="
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
echo "✅ kubectl 설정 완료"

# ── EC2 user_data 완료 대기 ─────────────────────────────────────
echo ""
echo "=== [3/5] EC2 초기화 대기 (최대 10분) ==="
ELAPSED=0
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
         -i "$KEY_PATH" "ec2-user@$EC2_IP" \
         "test -f /var/log/user_data_done" 2>/dev/null; do
  echo "  ... 대기 중 (${ELAPSED}초 경과)"
  sleep 30
  ELAPSED=$((ELAPSED + 30))
  if [ $ELAPSED -ge 600 ]; then
    echo "❌ user_data 타임아웃 — EC2에 SSH 접속 후 /var/log/user_data.log 확인"
    exit 1
  fi
done
echo "✅ EC2 초기화 완료"

# kubeconfig EC2에 전송
scp -o StrictHostKeyChecking=no -i "$KEY_PATH" \
    ~/.kube/config "ec2-user@$EC2_IP:~/.kube/config"

# ── Phase 2: 플랫폼 설치 ────────────────────────────────────────
echo ""
echo "=== [4/5] 플랫폼 설치 (Istio + 모니터링 + Chaos Mesh + Online Boutique) ==="
cd "$SCRIPT_DIR/../terraform/2-platform"
terraform init -input=false 2>&1 | tee -a "$LOG_FILE"
terraform apply -auto-approve -compact-warnings -input=false 2>&1 | tee -a "$LOG_FILE"
echo "✅ 플랫폼 설치 완료"

# ── EC2에서 포트포워드 + Next.js 시작 ───────────────────────────
echo ""
echo "=== [5/5] EC2 서비스 시작 ==="

# terraform apply 완료 후에도 pod 기동까지 추가 시간 필요 — Ready 확인 후 port-forward
echo "  Prometheus/Loki pod Ready 대기 (최대 5분)..."
ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "ec2-user@$EC2_IP" \
  "kubectl wait --for=condition=ready pod \
   -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s 2>/dev/null || true && \
   kubectl wait --for=condition=ready pod \
   -l app.kubernetes.io/name=loki -n monitoring --timeout=300s 2>/dev/null || true"

# setsid + stdin=/dev/null → SSH 세션 종료 후에도 프로세스 유지
ssh -f -o StrictHostKeyChecking=no -i "$KEY_PATH" "ec2-user@$EC2_IP" \
  "setsid nohup kubectl port-forward svc/kube-prometheus-stack-prometheus \
   -n monitoring 9090:9090 </dev/null >/var/log/pf-prometheus.log 2>&1"

ssh -f -o StrictHostKeyChecking=no -i "$KEY_PATH" "ec2-user@$EC2_IP" \
  "setsid nohup kubectl port-forward svc/loki \
   -n monitoring 3100:3100 </dev/null >/var/log/pf-loki.log 2>&1"

# Next.js: 빌드 완료 여부 확인 후 시작
NEXTJS_BUILT=$(ssh -o StrictHostKeyChecking=no -i "$KEY_PATH" "ec2-user@$EC2_IP" \
  "test -f /var/log/nextjs_build_done && echo yes || echo no")

if [ "$NEXTJS_BUILT" = "yes" ]; then
  ssh -f -o StrictHostKeyChecking=no -i "$KEY_PATH" "ec2-user@$EC2_IP" \
    "cd ~/iac-nextjs && setsid nohup npm start </dev/null >/var/log/nextjs.log 2>&1"
  echo "✅ Next.js 시작됨"
else
  echo "⚠️  Next.js 빌드 미완료 — Phase 2 완료 후 EC2에서 수동 시작:"
  echo "   ssh -i $KEY_PATH ec2-user@$EC2_IP"
  echo "   cd ~/iac-nextjs && npm run build && npm start &"
fi

echo ""
echo "══════════════════════════════════════════════"
echo "   ✅ 구축 완료!"
echo "══════════════════════════════════════════════"
echo "   대시보드:    http://$EC2_IP:3000"
echo "   SSH:         ssh -i $KEY_PATH ec2-user@$EC2_IP"
echo "   Prometheus:  http://$EC2_IP:9090 (SSH 터널 후)"
echo ""
echo "   Online Boutique LoadBalancer IP:"
echo "   kubectl get svc frontend-external -n online-boutique"
echo "══════════════════════════════════════════════"

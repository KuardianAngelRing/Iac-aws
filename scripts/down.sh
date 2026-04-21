#!/usr/bin/env bash
# EKS 전체 삭제 스크립트 — 실행 후 AWS 비용 $0
# 주의: 모든 리소스가 삭제됩니다 (EKS, EC2, VPC, NAT Gateway 포함)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "══════════════════════════════════════════════"
echo "   ⚠️  전체 AWS 리소스 삭제를 시작합니다"
echo "   이 작업은 되돌릴 수 없습니다."
echo "══════════════════════════════════════════════"
read -p "계속하시겠습니까? (yes 입력): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "취소됨."
  exit 0
fi

# ── LoadBalancer 사전 삭제 ───────────────────────────────────────
# Online Boutique의 ELB가 남아있으면 VPC destroy가 영구히 멈춤
echo ""
echo "=== [0/2] LoadBalancer 서비스 사전 삭제 ==="
if command -v kubectl &>/dev/null; then
  aws eks update-kubeconfig --name chaos-eks --region ap-northeast-2 2>/dev/null || true
  kubectl delete svc -n online-boutique --all --timeout=90s 2>/dev/null || true
  echo "  LoadBalancer 삭제 완료 (또는 이미 없음)"
else
  echo "  kubectl 없음 — 건너뜀 (EKS 접근 불가 시 정상)"
fi

# ── Phase 2 플랫폼 삭제 ─────────────────────────────────────────
echo ""
echo "=== [1/2] 플랫폼 삭제 (Helm 릴리스 + K8s 리소스) ==="
cd "$SCRIPT_DIR/../terraform/2-platform"
terraform destroy -auto-approve || {
  echo "WARNING: 2-platform destroy 중 오류 발생 — 계속 진행"
}

# ── Phase 1 인프라 삭제 ─────────────────────────────────────────
echo ""
echo "=== [2/2] 인프라 삭제 (EKS + EC2 + VPC + NAT Gateway) ==="
cd "$SCRIPT_DIR/../terraform/1-base"
terraform destroy -auto-approve

echo ""
echo "══════════════════════════════════════════════"
echo "   ✅ 전체 삭제 완료!"
echo "   AWS 비용: \$0 (Supabase 제외)"
echo ""
echo "   재구축: ./scripts/up.sh"
echo "══════════════════════════════════════════════"

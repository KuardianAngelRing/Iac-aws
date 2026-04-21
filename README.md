# Chaos EKS

<div align="center">

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-7B42BC?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![EKS](https://img.shields.io/badge/EKS-1.30-326CE5?style=for-the-badge&logo=kubernetes)](https://aws.amazon.com/eks/)
[![Chaos Mesh](https://img.shields.io/badge/Chaos_Mesh-2.6-FF4D4F?style=for-the-badge)](https://chaos-mesh.org/)
[![LangGraph](https://img.shields.io/badge/LangGraph-AI_Loop-00B96B?style=for-the-badge)](https://langchain-ai.github.io/langgraph/)

**AWS EKS + Chaos Mesh 기반 AI 자동 장애복구 파이프라인**

</div>

---

## 아키텍처

```
              Supabase (Cloud DB)
                     ▲
                     │ 
                     │
              EC2 (GitOps이자 카오스 테스트 대시보드용)
              ├── Next.js :3000   (대시보드)
              └── worker.py       (AI Agent 루프)
                       │
                       │ kubectl port-forward (9090 / 3100)
                       │ K8s API (chaos CRD apply)
                       ▼
      ┌────────────────────────────────────┐
      │           EKS Cluster              │
      │  ┌─────────────┐  ┌─────────────┐  │
      │  │ On-demand   │  │  Spot × 3   │  │
      │  │ m5.large    │  │  m5.xlarge  │  │
      │  │─────────────│  │─────────────│  │
      │  │ Prometheus  │  │ Istio mesh  │  │
      │  │ Grafana     │  │ Online      │  │
      │  │ Loki        │  │ Boutique    │  │
      │  │ Chaos Mesh  │  │ (SUT)       │  │
      │  └─────────────┘  └─────────────┘  │
      └────────────────────────────────────┘
```

### AI 루프 동작 방식

Online Boutique(실험 대상)에 네트워크 지연·파드 장애 등 카오스를 주입한 뒤,
LangGraph 기반 멀티에이전트가 아래 사이클을 자동으로 반복합니다.

| 단계 | 에이전트 | 역할 |
|------|---------|------|
| 1 | **Observer** | Prometheus에서 에러율·레이턴시·복구 시간 수집 |
| 2 | **Analyst** | Claude API 호출 — 장애 원인 및 병목 분석 |
| 3 | **Recommender** | Istio timeout / retry / circuit-breaker 파라미터 추천 |
| 4 | **Executor** | `kubectl patch`로 VirtualService·DestinationRule 즉시 적용 |
| 5 | **Verifier** | R 지수(회복 탄력성 지수) 재측정 → 개선되면 종료, 아니면 반복 |

> **R 지수** = 0.4 × 가용성 + 0.3 × 레이턴시 점수 + 0.3 × 복구 속도. 루프 종료 시 Before/After 비교 리포트 생성

---

## 구조

```
Iac-aws/
├── terraform/
│   ├── 1-base/        # VPC + EKS + EC2
│   └── 2-platform/    # Istio + 모니터링 + Chaos Mesh
├── worker/            # LangGraph AI 루프 (Phase 3)
├── scripts/
│   ├── up.sh          # 전체 구축
│   └── down.sh        # 전체 삭제 
├── chaos-experiments/ # Chaos Mesh CRD
└── argocd/            # GitOps (Phase 4)
```

---

## 시작하기

```bash
# 환경설정 파일 구성 필요 - /worker/.env & /terraform/1-base/terraform.tfvars

# 구축 (~20분)
./scripts/up.sh
## [1/5] terraform apply 1-base     ← EKS 생성만 ~15분                          
## [2/5] kubeconfig 설정
## [3/5] EC2 user_data 완료 대기    ← Node.js/Python 설치, 레포 클론
## [4/5] terraform apply 2-platform ← Istio/모니터링/Chaos Mesh/Online Boutique
## [5/5] EC2 port-forward + Next.js 시작  

# 삭제 (비용 $0)
./scripts/down.sh
## "yes" 입력 → 전체 삭제 → 비용 $0 
```

---

## 커밋 컨벤션

| 이모지 | 용도 |
|--------|------|
| ✨ | 새 기능 |
| 🐛 | 버그 수정 |
| ♻️ | 리팩토링 |
| 🔧 | 설정 변경 (Terraform, Helm values 등) |
| 📝 | 문서 |
| 🚀 | 배포 / 인프라 |
| 🔥 | 코드·파일 삭제 |

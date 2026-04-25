<div align="center">

<img src="./docs/assets/hero.png" alt="KuardianAngelRing" width="300"/>

# 🛡️ KuardianAngelRing

### **AI-Powered Self-Healing Pipeline for Kubernetes Chaos Test**

**카오스 테스트 주입 → AI 분석 → Istio 파라미터 자동 튜닝 → 회복 검증**, AI agent 기반 정밀 자가복구 파이프라인

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![EKS](https://img.shields.io/badge/EKS-1.31-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://aws.amazon.com/eks/)
[![Istio](https://img.shields.io/badge/Istio-1.29-466BB0?style=for-the-badge&logo=istio&logoColor=white)](https://istio.io/)
[![Chaos Mesh](https://img.shields.io/badge/Chaos_Mesh-2.8-FF4D4F?style=for-the-badge)](https://chaos-mesh.org/)
[![LangGraph](https://img.shields.io/badge/LangGraph-AI_Loop-00B96B?style=for-the-badge)](https://langchain-ai.github.io/langgraph/)
[![Claude](https://img.shields.io/badge/Claude-Sonnet_4.6-D97757?style=for-the-badge)](https://www.anthropic.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](./LICENSE)

[**🚀 Quick Start**](#-quick-start) ·
[**🏗️ Architecture**](#%EF%B8%8F-architecture) ·
[**🤖 AI Loop**](#-ai-loop) ·
[**🐛 Troubleshooting**](#-troubleshooting) ·
[**🗺️ Roadmap**](#%EF%B8%8F-roadmap)

</div>

---

## 🏗️ Architecture

<div align="center">
<img src="./docs/assets/architecture.svg" alt="Architecture Diagram" width="900"/>
</div>

---

## 🤖 AI Loop

Online Boutique(SUT)에 카오스가 주입되면, **AI 에이전트들**이 협력해 회복탄력성을 자동으로 끌어올립니다.

<div align="center">

```mermaid
graph LR
    Chaos[💥 Chaos Injection] --> Observer
    Observer[👁️ Observer<br/>Prometheus 메트릭 수집] --> Analyst
    Analyst[🧠 Analyst<br/>Claude API 분석] --> Recommender
    Recommender[💡 Recommender<br/>Istio 파라미터 추천] --> Executor
    Executor[⚙️ Executor<br/>kubectl patch 적용] --> Verifier
    Verifier{🎯 Verifier<br/>R 지수 개선?}
    Verifier -- Yes --> Done[✅ 종료 + 리포트]
    Verifier -- No --> Recommender

    style Chaos fill:#FF4D4F,color:#fff
    style Analyst fill:#D97757,color:#fff
    style Done fill:#00B96B,color:#fff
```

</div>

| 단계 | 에이전트 | 역할 |
|:---:|---|---|
| 1 | 👁️ **Observer** | Prometheus에서 에러율 · p99 레이턴시 · MTTR 수집 |
| 2 | 🧠 **Analyst** | Claude API 호출 — 장애 원인 / 병목 / 가설 도출 |
| 3 | 💡 **Recommender** | Istio `timeout` / `retry` / `circuitBreaker` 파라미터 제안 (범위 검증) |
| 4 | ⚙️ **Executor** | `kubectl patch`로 VirtualService · DestinationRule 즉시 적용 |
| 5 | 🎯 **Verifier** | R 지수 재측정 → 개선 시 종료, 아니면 ④ 재반복 (max 5 iter) |

### 📐 R 지수 (Resilience Index)

```
R = 0.4 × Availability + 0.3 × LatencyScore + 0.3 × RecoverySpeed
```

| 가중치 | 메트릭 | 정의 |
|:---:|---|---|
| **0.4** | Availability | `1 - (5xx 응답 / 전체 응답)` |
| **0.3** | LatencyScore | `min(1, p99_baseline / p99_current)` |
| **0.3** | RecoverySpeed | `1 - clip(MTTR / 60s, 0, 1)` |

루프 종료 시 **Before / After 비교 리포트** 자동 생성 → Supabase에 저장 → Next.js 대시보드 시각화

---

## 🛠️ Tech Stack

<div align="center">

| Layer | Technology |
|---|---|
| **☁️  Cloud** | AWS (EKS, EC2, VPC, NAT, KMS, EBS, IAM) |
| **🏗️  IaC** | Terraform 1.6+, terraform-aws-modules/eks v20 |
| **☸️  Orchestration** | Kubernetes 1.31, Helm 3.x |
| **🔀  Service Mesh** | Istio 1.29 (sidecar mode) |
| **💥  Chaos** | Chaos Mesh 2.8 |
| **📊  Observability** | Prometheus, Grafana, Loki, Promtail |
| **🤖  AI** | Anthropic Claude (Sonnet 4.6), LangGraph |
| **💾  Realtime DB** | Supabase (Postgres + Realtime) |
| **🎨  Dashboard** | Next.js 14 (App Router, FSD 2.1+), TypeScript |
| **🚀  GitOps** | ArgoCD |
| **🛒  SUT** | Google Cloud Online Boutique (11 microservices) |

</div>

---

## 📁 Repository Structure

```
KuardianAngelRing/
├── 📦 terraform/
│   ├── 1-base/              # VPC + EKS + EC2 + IRSA
│   └── 2-platform/          # Istio + 모니터링 + Chaos Mesh + Boutique
├── 🤖 worker/               # LangGraph AI 루프 (Python)
├── 🎨 ../iac-nextjs/        # Next.js 14 대시보드 (별도 레포)
├── 🚀 argocd/               # GitOps Application 매니페스트
├── 💥 chaos-experiments/    # 카오스 시나리오 모음 (CRD YAML)
└── 📜 scripts/
    ├── up.sh               # 전체 자동 구축
    └── down.sh             # 전체 정리 ($0)
```

---

## 🚀 Quick Start

### 1️⃣ 로컬 도구 설치

```bash
# macOS (Homebrew)
brew install terraform awscli kubectl helm

# 버전 확인
terraform -version    # >= 1.6
aws --version
kubectl version --client
helm version
```

### 2️⃣ AWS 자격증명

```bash
aws configure
# Region: ap-northeast-2
aws sts get-caller-identity   # 자격증명 검증
```

### 3️⃣ EC2 Key Pair 생성

AWS 콘솔 → EC2 → Key Pairs → **Create key pair** → 이름 `chaos-eks-key`, 포맷 `.pem` → 다운로드

```bash
mv ~/Downloads/chaos-eks-key.pem ~/.ssh/
chmod 400 ~/.ssh/chaos-eks-key.pem
```

### 4️⃣ Spot vCPU 쿼터 확인 *(선택)*

`m5.xlarge × 2 = 8 vCPU` 사용. 신규 계정은 보통 5 vCPU 한도라 부족할 수 있음

```bash
aws service-quotas get-service-quota \
  --service-code ec2 --quota-code L-34B43A08 \
  --region ap-northeast-2 --query 'Quota.Value'
```

### 5️⃣ `terraform.tfvars` 작성

```bash
cd terraform/1-base
```

`terraform/1-base/terraform.tfvars`
```hcl
aws_region   = "ap-northeast-2"
key_name     = "chaos-eks-key"
iac_aws_repo = "https://github.com/<your-org>/Iac-aws"
my_ip_cidr   = "0.0.0.0/0"   # 본인 IP/32 권장 (보안)
```

### 6️⃣ 구축 실행

```bash
cd ../..
./scripts/up.sh
```

| 단계 | 작업 | 소요 |
|:---:|---|:---:|
| **[1/5]** | `terraform apply 1-base` — VPC + EKS + EC2 + 노드그룹 | ~14분 |
| **[2/5]** | 로컬 kubeconfig 설정 | 즉시 |
| **[3/5]** | EC2 user_data — kubectl/helm/git 설치 | ~2분 |
| **[4/5]** | `terraform apply 2-platform` — Istio + 모니터링 + Chaos + SUT | ~6~8분 |
| **[5/5]** | port-forward (Prometheus 9090, Loki 3100) | ~1분 |

### 7️⃣ 접속 / 검증

> 모든 kubectl 명령은 **로컬 머신에서 직접** 실행 (`up.sh`가 kubeconfig 자동 설정)

#### 🛒 Online Boutique
```bash
kubectl get svc frontend-external -n online-boutique
# EXTERNAL-IP의 ELB 주소를 브라우저에 입력
```

#### ⚙️ Chaos Mesh Dashboard
```bash
kubectl port-forward svc/chaos-dashboard -n chaos-mesh 2333:2333
# → http://localhost:2333
```

#### 📊 Grafana
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# → http://localhost:3000
```


### 8️⃣ 정리 (비용 $0)

```bash
./scripts/down.sh   # yes 입력
```

→ 약 10~15분 후 모든 AWS 리소스 삭제. **Supabase 외 시간당 과금 0원**


## 🗺️ Roadmap

- [x] **Phase 1** — EKS 인프라 + Chaos Mesh + 모니터링 자동 구축
- [x] **Phase 2** — Next.js 14 + Supabase Realtime 대시보드
- [x] **Phase 3** — LangGraph AI 루프 + R 지수 자동 개선
- [x] **Phase 4** — ArgoCD GitOps + sample-app 선언적 관리
- [x] **Phase 5** — End-to-end 시연 + Before/After 리포트 자동화

---

## 📝 Commit Convention

| 이모지 | 용도 |
|:---:|---|
| ✨ | 새 기능 |
| 🐛 | 버그 수정 |
| ♻️ | 리팩토링 |
| 🔧 | 설정 변경 (Terraform, Helm values 등) |
| 📝 | 문서 |
| 🚀 | 배포 / 인프라 |
| 🔥 | 코드·파일 삭제 |

---

## 🤝 Contributing

이 프로젝트는 졸업과제로 시작했지만, 카오스 엔지니어링 + AI 자가복구에 관심 있는 분들의 기여를 환영합니다.

1. Fork & branch (`git checkout -b feature/amazing`)
2. Commit (`✨ Add amazing feature`)
3. Push & open Pull Request

---


<div align="center">

**🛡️ Built with chaos in mind, powered by AI to heal.**

[⬆ Back to top](#%EF%B8%8F-kuardianangelring)

</div>

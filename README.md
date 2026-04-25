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

### 1. 로컬 도구 설치

macOS 기준 (Homebrew)
```bash
brew install terraform awscli kubectl helm
```

버전 확인
```bash
terraform -version    # >= 1.6
aws --version
kubectl version --client
helm version
```

### 2. AWS 자격증명 설정

```bash
aws configure
# AWS Access Key ID:     <IAM 사용자 키>
# AWS Secret Access Key: <시크릿>
# Default region:        ap-northeast-2
# Default output format: json
```

확인
```bash
aws sts get-caller-identity
```

> IAM 사용자에게 **AdministratorAccess** 권한 필요

### 3. EC2 Key Pair 생성

AWS 콘솔 → EC2 → Key Pairs → **Create key pair** → 이름 `chaos-eks-key`, 포맷 `.pem` → 다운로드

다운로드 받은 `.pem` 파일을 `~/.ssh/`로 옮기고 권한 설정
```bash
mv ~/Downloads/chaos-eks-key.pem ~/.ssh/
chmod 400 ~/.ssh/chaos-eks-key.pem
```

### 4. Spot vCPU 쿼터 확인 (선택)

`m5.xlarge × 2 = 8 vCPU` 사용. 기본 한도 5 vCPU면 부족할 수 있음

```bash
aws service-quotas get-service-quota \
  --service-code ec2 --quota-code L-34B43A08 \
  --region ap-northeast-2 --query 'Quota.Value'
```

> 8 미만이면 AWS 콘솔 → Service Quotas → "All Standard Spot Instance Requests"에서 증설 신청

### 5. `terraform.tfvars` 작성

```bash
cd terraform/1-base
cp terraform.tfvars.example terraform.tfvars 
```

`terraform/1-base/terraform.tfvars` 내용
```hcl
aws_region   = "ap-northeast-2"
key_name     = "chaos-eks-key"        # 3단계에서 만든 Key Pair 이름
iac_aws_repo = "https://github.com/<your-org>/Iac-aws"
my_ip_cidr   = "0.0.0.0/0"            # 본인 IP/32 권장 (보안)
```

### 6. 구축 실행

```bash
cd ../..              
./scripts/up.sh
```

소요 약 22~28분. 5단계 자동 진행:
```
[1/5] terraform apply 1-base       ← VPC + EKS + EC2 + 노드그룹 (~14분)
[2/5] 로컬 kubeconfig 설정          ← 즉시
[3/5] EC2 user_data 완료 대기       ← kubectl/helm/git 설치 (~2분)
[4/5] terraform apply 2-platform   ← Istio + 모니터링 + Chaos Mesh + Online Boutique (~6~8분)
[5/5] EC2 port-forward 시작        ← Prometheus 9090 / Loki 3100
```

### 7. 접속 / 검증

모든 kubectl 명령은 **로컬 맥에서 직접** 실행 (`./scripts/up.sh`가 kubeconfig 자동 설정)

#### 🛒 Online Boutique 사이트
```bash
kubectl get svc frontend-external -n online-boutique
```
→ EXTERNAL-IP의 ELB 주소를 브라우저에 입력.

#### ⚙️ Chaos Mesh Dashboard (실험 GUI)
```bash
kubectl port-forward svc/chaos-dashboard -n chaos-mesh 2333:2333
```
→ 브라우저: `http://localhost:2333`

#### 📊 Grafana
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```
→ 브라우저: `http://localhost:3000`

### 8. 종료 (비용 $0)

```bash
./scripts/down.sh
```
→ `yes` 입력 → 약 10~15분 후 모든 AWS 리소스 삭제

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

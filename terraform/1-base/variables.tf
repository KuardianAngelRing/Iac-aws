variable "aws_region" {
  description = "AWS 리전"
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  default     = "chaos-eks"
}

variable "key_name" {
  description = "EC2 Key Pair 이름 (ap-northeast-2에서 생성한 것)"
  type        = string
}

variable "iac_aws_repo" {
  description = "Iac-aws GitHub 레포 URL"
  type        = string
}

variable "iac_nextjs_repo" {
  description = "iac-nextjs GitHub 레포 URL"
  type        = string
}

variable "supabase_url" {
  description = "Supabase 프로젝트 URL"
  type        = string
}

variable "supabase_key" {
  description = "Supabase anon key"
  type        = string
  sensitive   = true
}

variable "anthropic_key" {
  description = "Anthropic API Key (Phase 3에서 사용)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "my_ip_cidr" {
  description = "관리자 IP CIDR (SSH + EKS endpoint + Next.js 접근 제한). 예: 123.45.67.89/32"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tfstate_bucket" {
  description = "Terraform 상태 S3 버킷 (선택 — 팀 협업 시)"
  default     = ""
}

variable "tfstate_region" {
  default = "ap-northeast-2"
}

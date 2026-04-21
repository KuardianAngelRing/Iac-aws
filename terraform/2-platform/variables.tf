variable "aws_region" {
  default = "ap-northeast-2"
}

variable "cluster_name" {
  default = "chaos-eks"
}

variable "grafana_admin_password" {
  description = "Grafana 관리자 비밀번호 (terraform.tfvars에서 반드시 변경)"
  type        = string
  default     = "ChangeMe123!"
  sensitive   = true
}

output "ec2_public_ip" {
  description = "EC2 제어 서버 Public IP"
  value       = aws_instance.control.public_ip
}

output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API 엔드포인트"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

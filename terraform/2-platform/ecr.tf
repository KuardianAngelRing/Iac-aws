# Argo Workflows(Kaniko)가 ECR에 이미지를 push하기 위한 IRSA.
# argo 네임스페이스의 'argo-workflow' ServiceAccount가 이 role을 assume.

data "aws_caller_identity" "current" {}

# 1-base에서 EKS가 만든 OIDC provider를 2-platform state에서 참조.
data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

locals {
  oidc_host = replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")
}

resource "aws_iam_role" "argo_workflows_ecr" {
  name = "${var.cluster_name}-argo-ecr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.eks.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_host}:sub" = "system:serviceaccount:argo:argo-workflow"
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# push/pull/create layer 등 빌드 이미지 업로드에 필요한 권한.
resource "aws_iam_role_policy_attachment" "argo_ecr_power" {
  role       = aws_iam_role.argo_workflows_ecr.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

output "ecr_registry" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "argo_workflows_ecr_role_arn" {
  value = aws_iam_role.argo_workflows_ecr.arn
}

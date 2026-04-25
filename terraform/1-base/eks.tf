module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  vpc_id                               = module.vpc.vpc_id
  subnet_ids                           = module.vpc.private_subnets
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = [var.my_ip_cidr]

  # terraform apply 실행 IAM User → 자동으로 cluster-admin 권한 부여
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  # API 서버 → istiod webhook(targetPort 15017) 호출 허용.
  # 기본 EKS 모듈은 4443/6443/8443/9443/443만 열어 두므로 Istio 1.x의
  # 비표준 포트 15017이 막혀 sidecar-injector webhook 호출이 silent timeout 발생.
  node_security_group_additional_rules = {
    ingress_cluster_istiod_webhook = {
      description                   = "Cluster API to istiod webhook (15017)"
      protocol                      = "tcp"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # EC2 IAM Role → EKS cluster-admin (kubectl 사용을 위해)
  access_entries = {
    ec2_access = {
      principal_arn = aws_iam_role.ec2_role.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    # On-demand: Prometheus + Grafana + Loki + Chaos Mesh 컨트롤러 전용
    system = {
      name           = "system"
      instance_types = ["m5.xlarge"]
      capacity_type  = "ON_DEMAND"

      min_size     = 1
      max_size     = 2
      desired_size = 1

      taints = {
        system_only = {
          key    = "system-only"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      labels = { role = "system" }
    }

    # Spot: Istio + Online Boutique 워크로드
    workload = {
      name           = "workload"
      instance_types = ["m5.xlarge", "m5.2xlarge", "m4.xlarge"] # 3개 타입으로 Spot 가용성 확보
      capacity_type  = "SPOT"

      min_size     = 2
      max_size     = 5
      desired_size = 2 # Spot 쿼터 32 vCPU 승인 후 3으로 변경

      labels = { role = "workload" }
    }
  }

  tags = local.common_tags
}

# EBS CSI driver가 EBS 볼륨을 동적 프로비저닝하기 위한 IRSA.
# EKS는 EBS CSI driver를 자동 설치하지 않으며 (1.23+), driver는 자체 IAM 권한이 필요함.
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

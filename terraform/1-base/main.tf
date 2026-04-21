terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 팀 협업 시 S3 backend 활성화 (먼저 버킷 수동 생성 필요):
  # backend "s3" {
  #   bucket         = "chaos-eks-tfstate"
  #   key            = "1-base/terraform.tfstate"
  #   region         = "ap-northeast-2"
  #   dynamodb_table = "chaos-eks-tfstate-lock"
  # }
}

provider "aws" {
  region = var.aws_region
}

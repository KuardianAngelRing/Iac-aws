# Argo Workflows — in-cluster 빌드 엔진(Kaniko 실행). 컨트롤러/서버는 system 노드,
# 빌드 워크플로 Pod는 toleration 없이 workload(spot) 노드에 스케줄.
resource "helm_release" "argo_workflows" {
  name             = "argo-workflows"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-workflows"
  namespace        = "argo"
  version          = "0.45.8"
  create_namespace = false
  timeout          = 300

  values = [
    <<-YAML
    controller:
      nodeSelector:
        role: system
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
    server:
      enabled: true
      nodeSelector:
        role: system
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
      # 단일 사용자 + port-forward → 인증 생략
      authModes:
        - server
    YAML
  ]

  depends_on = [kubernetes_namespace.argo]
}

# 빌드 워크플로(Kaniko)가 사용하는 SA — IRSA로 ECR push 권한 부여.
resource "kubernetes_service_account" "argo_workflow" {
  metadata {
    name      = "argo-workflow"
    namespace = "argo"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argo_workflows_ecr.arn
    }
  }

  depends_on = [kubernetes_namespace.argo]
}

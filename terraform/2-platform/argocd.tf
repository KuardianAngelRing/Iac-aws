# ArgoCD — GitOps 배포(App-of-Apps). git의 argocd/apps/ 를 watch하여
# SUT 앱 Application을 자동 등록·sync. system 노드에 설치.
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = "7.7.11"
  create_namespace = false
  timeout          = 600

  values = [
    <<-YAML
    global:
      nodeSelector:
        role: system
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
    configs:
      params:
        # EC2 port-forward 뒤에서 단일 사용자 접근 → TLS 생략(인증 v1 생략 정책과 일관)
        server.insecure: true
    dex:
      enabled: false
    notifications:
      enabled: false
    YAML
  ]

  depends_on = [kubernetes_namespace.argocd]
}

output "argocd_note" {
  value = "ArgoCD 초기 admin 비밀번호: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

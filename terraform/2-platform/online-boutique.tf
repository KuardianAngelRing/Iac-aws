resource "helm_release" "online_boutique" {
  name      = "onlineboutique"
  chart     = "oci://us-docker.pkg.dev/online-boutique-ci/charts/onlineboutique"
  namespace = "online-boutique"
  timeout   = 600

  # Spot 노드에서 실행 (workload 노드 그룹)
  values = [
    <<-YAML
    frontend:
      externalService: true  # LoadBalancer 타입 — 외부 접근용
    YAML
  ]

  depends_on = [
    kubernetes_namespace.online_boutique,
    helm_release.istiod,
  ]
}

output "online_boutique_note" {
  value = "frontend LoadBalancer IP: kubectl get svc frontend-external -n online-boutique"
}

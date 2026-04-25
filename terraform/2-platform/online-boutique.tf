resource "helm_release" "online_boutique" {
  name      = "onlineboutique"
  chart     = "oci://us-docker.pkg.dev/online-boutique-ci/charts/onlineboutique"
  version   = "0.10.5"
  namespace = "online-boutique"
  timeout   = 600

  values = [
    <<-YAML
    frontend:
      externalService: true
    YAML
  ]

  depends_on = [
    kubernetes_namespace.online_boutique,
    helm_release.istiod,
    null_resource.wait_istiod_webhook,
  ]
}

output "online_boutique_note" {
  value = "frontend LoadBalancer IP: kubectl get svc frontend-external -n online-boutique"
}

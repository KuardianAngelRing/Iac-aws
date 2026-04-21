resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  namespace        = "istio-system"
  version          = "1.29.2"
  create_namespace = false

  depends_on = [kubernetes_namespace.istio_system]
}

resource "helm_release" "istiod" {
  name             = "istiod"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "istiod"
  namespace        = "istio-system"
  version          = "1.29.2"
  create_namespace = false
  timeout          = 300

  values = [
    <<-YAML
    meshConfig:
      defaultConfig:
        proxyStatsMatcher:
          inclusionRegexps:
            - ".*"
    YAML
  ]

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_gateway" {
  name             = "istio-ingress"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  namespace        = "istio-system"
  version          = "1.29.2"
  create_namespace = false

  depends_on = [helm_release.istiod]
}

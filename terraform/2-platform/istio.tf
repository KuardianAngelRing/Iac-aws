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

# Helm은 차트 적용 직후 "deployed"로 마크하지만 mutating webhook은
# 아직 요청을 받지 못하는 상태. 후속 차트가 즉시 Pod를 만들면
# webhook 호출이 timeout되며 ReplicaSet FailedCreate 발생.
# deployment available + pod ready + 추가 sleep 으로 webhook serving 보장.
resource "null_resource" "wait_istiod_webhook" {
  depends_on = [helm_release.istiod]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl wait --for=condition=available deployment/istiod \
        -n istio-system --timeout=300s
      kubectl wait --for=condition=ready pod \
        -l app=istiod -n istio-system --timeout=120s
      sleep 20
    EOT
  }
}

resource "helm_release" "istio_gateway" {
  name             = "istio-ingress"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "gateway"
  namespace        = "istio-system"
  version          = "1.29.2"
  create_namespace = false

  depends_on = [
    helm_release.istiod,
    null_resource.wait_istiod_webhook,
  ]
}

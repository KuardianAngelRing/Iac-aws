resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  version          = "83.7.0"
  create_namespace = false
  timeout          = 600

  values = [
    <<-YAML
    prometheus:
      prometheusSpec:
        tolerations:
          - key: system-only
            operator: Equal
            value: "true"
            effect: NoSchedule
        nodeSelector:
          role: system
        scrapeInterval: 15s
        retention: 7d
        additionalScrapeConfigs:
          - job_name: istio-mesh
            kubernetes_sd_configs:
              - role: endpoints
                namespaces:
                  names:
                    - istio-system
                    - online-boutique

    grafana:
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
      nodeSelector:
        role: system
      additionalDataSources:
        - name: Loki
          type: loki
          url: http://loki:3100
          access: proxy

    alertmanager:
      alertmanagerSpec:
        tolerations:
          - key: system-only
            operator: Equal
            value: "true"
            effect: NoSchedule
        nodeSelector:
          role: system
    YAML
  ]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# loki-stack(deprecated) → loki 6.x SingleBinary 모드로 교체
resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  namespace        = "monitoring"
  version          = "6.7.3"
  create_namespace = false
  timeout          = 300

  values = [
    <<-YAML
    deploymentMode: SingleBinary
    loki:
      auth_enabled: false
      commonConfig:
        replication_factor: 1
      storage:
        type: filesystem
      schemaConfig:
        configs:
          - from: "2024-01-01"
            store: tsdb
            object_store: filesystem
            schema: v13
            index:
              prefix: loki_index_
              period: 24h
    singleBinary:
      replicas: 1
      # Loki 6.x: storage.type=filesystem 사용 시 persistence 필수.
      # 비활성화하면 컨테이너 read-only rootfs에서 /var/loki mkdir 실패.
      persistence:
        enabled: true
        size: 5Gi
        storageClass: gp2
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
      nodeSelector:
        role: system
    gateway:
      enabled: false
    backend:
      replicas: 0
    read:
      replicas: 0
    write:
      replicas: 0
    YAML
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "promtail" {
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  namespace        = "monitoring"
  version          = "6.16.4"
  create_namespace = false
  timeout          = 180

  values = [
    <<-YAML
    config:
      clients:
        - url: http://loki:3100/loki/api/v1/push
    tolerations:
      - key: system-only
        operator: Equal
        value: "true"
        effect: NoSchedule
      - operator: Exists
    YAML
  ]

  depends_on = [helm_release.loki]
}

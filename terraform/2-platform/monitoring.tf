resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  version          = "61.7.0"
  create_namespace = false
  timeout          = 600

  values = [
    <<-YAML
    # On-demand(system) 노드에만 스케줄링
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

    grafana:
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
      nodeSelector:
        role: system
      adminPassword: "admin123"
      # Loki 데이터소스 자동 연결
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

    # Istio 메트릭 수집을 위한 추가 스크랩 설정
    prometheus:
      prometheusSpec:
        additionalScrapeConfigs:
          - job_name: istio-mesh
            kubernetes_sd_configs:
              - role: endpoints
                namespaces:
                  names:
                    - istio-system
                    - online-boutique
    YAML
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

resource "helm_release" "loki_stack" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  namespace        = "monitoring"
  version          = "2.10.2"
  create_namespace = false
  timeout          = 300

  values = [
    <<-YAML
    loki:
      persistence:
        enabled: false  # 개발 환경 — 영구 볼륨 불필요
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
      nodeSelector:
        role: system

    promtail:
      # DaemonSet이므로 모든 노드에서 실행 (toleration 필요)
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
        - operator: Exists
    YAML
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

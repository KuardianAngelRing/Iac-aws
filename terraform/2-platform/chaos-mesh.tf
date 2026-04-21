resource "helm_release" "chaos_mesh" {
  name             = "chaos-mesh"
  repository       = "https://charts.chaos-mesh.org"
  chart            = "chaos-mesh"
  namespace        = "chaos-mesh"
  version          = "2.8.2"
  create_namespace = false
  timeout          = 300

  values = [
    <<-YAML
    # Chaos Mesh 컨트롤러 → On-demand(system) 노드
    controllerManager:
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
      nodeSelector:
        role: system

    chaosDaemon:
      # DaemonSet — 모든 노드에서 실행해야 chaos 주입 가능
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
        - operator: Exists
      runtime: containerd
      socketPath: /run/containerd/containerd.sock

    dashboard:
      tolerations:
        - key: system-only
          operator: Equal
          value: "true"
          effect: NoSchedule
      nodeSelector:
        role: system
      securityMode: false  # 개발 환경 — 인증 없이 접근
    YAML
  ]

  depends_on = [kubernetes_namespace.chaos_mesh]
}

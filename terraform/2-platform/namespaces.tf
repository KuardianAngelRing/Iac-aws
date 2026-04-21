resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_namespace" "chaos_mesh" {
  metadata {
    name = "chaos-mesh"
  }
}

resource "kubernetes_namespace" "online_boutique" {
  metadata {
    name = "online-boutique"
    labels = {
      "istio-injection" = "enabled" # Istio 사이드카 자동 주입
    }
  }
}

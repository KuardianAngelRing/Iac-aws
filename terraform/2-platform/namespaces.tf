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

# ── Slice 2: GitOps + 빌드 + SUT ──────────────────────────────

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "argo" {
  metadata {
    name = "argo" # Argo Workflows (in-cluster 빌드)
  }
}

# 카오스 테스트 대상(SUT) 앱들이 GitOps로 배포되는 네임스페이스.
resource "kubernetes_namespace" "sut" {
  metadata {
    name = "sut"
    labels = {
      "istio-injection" = "enabled" # 사이드카 → NetworkChaos + 메트릭 수집
    }
  }
}

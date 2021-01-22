locals {
  namespace = "flux-system"
}

# SSH
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Flux
data "flux_install" "main" {
  target_path = var.repo_path
}

data "flux_sync" "main" {
  target_path = var.repo_path
  url         = "ssh://git@github.com/${var.github_owner}/${var.repo_name}.git"
  branch      = var.repo_branch
  namespace   = local.namespace
}

# Kubernetes
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = local.namespace
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }

}

# resource "null_resource" "flux_namespace" {

#   triggers = {
#     namespace = local.namespace
#   }

#   provisioner "local-exec" {
#     command = "kubectl create namespace $NAMESPACE"
#     environment = {
#       KUBECONFIG = var.kubeconfig_path
#       NAMESPACE = local.namespace
#     }
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = "kubectl delete namespace $NAMESPACE"
#     environment = {
#       KUBECONFIG = var.kubeconfig_path
#       NAMESPACE = local.namespace
#     }
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = "kubectl patch customresourcedefinition helmcharts.source.toolkit.fluxcd.io helmreleases.helm.toolkit.fluxcd.io helmrepositories.source.toolkit.fluxcd.io kustomizations.kustomize.toolkit.fluxcd.io -p '{\"metadata\":{\"finalizers\":null}}'"
#     environment = {
#       KUBECONFIG = var.kubeconfig_path
#     }
#   }

# }

data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}

resource "kubectl_manifest" "install" {
  for_each = { for v in data.kubectl_file_documents.install.documents : sha1(v) => v }
  depends_on = [kubernetes_namespace.flux_system]
  # depends_on = [null_resource.flux_namespace]

  yaml_body = each.value
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

resource "kubectl_manifest" "sync" {
  for_each   = { for v in data.kubectl_file_documents.sync.documents : sha1(v) => v }
  depends_on = [kubectl_manifest.install, kubernetes_namespace.flux_system]

  yaml_body = each.value
}

locals {
  known_hosts = "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=="
}

resource "kubernetes_secret" "main" {
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = data.flux_sync.main.name
    namespace = data.flux_sync.main.namespace
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }
}

data "github_repository" "main" {
  name = var.repo_name
}

resource "github_repository_deploy_key" "main" {
  title      = "flux-readonly"
  repository = data.github_repository.main.name
  key        = tls_private_key.main.public_key_openssh
  read_only  = true
}

resource "github_repository_file" "install" {
  repository = data.github_repository.main.name
  file       = data.flux_install.main.path
  content    = data.flux_install.main.content
  branch     = data.github_repository.main.default_branch

  lifecycle {
    ignore_changes = [
      content # Do not overwrite even if content has changed since bootstrapping Flux
    ]
  }
}

resource "github_repository_file" "sync" {
  repository = data.github_repository.main.name
  file       = data.flux_sync.main.path
  content    = data.flux_sync.main.content
  branch     = data.github_repository.main.default_branch
  depends_on = [github_repository_file.install]

  lifecycle {
    ignore_changes = [
      content # Do not overwrite even if content has changed since bootstrapping Flux
    ]
  }
}

resource "github_repository_file" "kustomize" {
  repository = data.github_repository.main.name
  file       = data.flux_sync.main.kustomize_path
  content    = data.flux_sync.main.kustomize_content
  branch     = data.github_repository.main.default_branch
  depends_on = [github_repository_file.sync]

  lifecycle {
    ignore_changes = [
      content # Do not overwrite even if content has changed since bootstrapping Flux
    ]
  }
}

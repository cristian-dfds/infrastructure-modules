terraform {
  required_version = "~> 1.0"

  required_providers {

    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

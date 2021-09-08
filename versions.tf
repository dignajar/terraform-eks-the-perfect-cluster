terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws        = ">= 3.50"
    local      = ">= 2.0"
    kubernetes = ">= 2.0"
  }
}
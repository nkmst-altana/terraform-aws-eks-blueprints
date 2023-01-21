# tflint-ignore: terraform_unused_declarations
variable "terratest_cluster_name" {
  description = "Name of cluster - used by Terratest for e2e test automation"
  type        = string
  default     = ""
}

variable "name" {
  description = "name of the cluster"
  type = string
}

variable "cluster_size" {
  description = "number of nodes in the cluster"
  type = number
}

variable "region" {
  description = "region for deployment"
  type = string
}

variable "allowed_account_ids" {
  description = "guard rail - make sure we are deploying in the right account"
  type = list(string)
}

variable "role_to_assume" {
  description = "role for terraform to use"
  type = string
}

variable "is_flyte_deploy" {
  description = "is this deploying flyte"
  type = bool
}

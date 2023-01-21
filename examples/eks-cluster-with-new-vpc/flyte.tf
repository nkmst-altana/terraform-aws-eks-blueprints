# these should probably be a different module we can include all at once

#-------------------------------------------------
# Flyte RDS
#-------------------------------------------------

#-------------------------------------------------
# Flyte S3 buckets
#-------------------------------------------------


#-------------------------------------------------
# Flyte helm addon
#-------------------------------------------------
locals {
  flyte_backend_service_account_name = "iam-role-flyte"
}

module "helm-addon" {
  source = "../../modules/kubernetes-addons/helm-addon"


  helm_config   = {
    name             = "flyte-backend"
    chart            = "flyteorg/flyte-binary"
    repository       = "https://flyteorg.github.io/flyte"
    version          = "v1.3.0"
    namespace        = "flyte"
    create_namespace = true
    values           =  [templatefile("./flyte_values.yaml", {
      service_account_name = locals.service_account_name
    })]
    description      = "flyte-binary helm deploy"
  }


  irsal_iam_role_name = local.flyte_backend_service_account_name

  addon_context = module.eks_blueprints_kubernetes_addons.addon_context
}

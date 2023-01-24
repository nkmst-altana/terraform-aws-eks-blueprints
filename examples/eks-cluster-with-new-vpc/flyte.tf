# these should probably be a different module we can include all at once, or implemented as a new kubernetes-addon in eks blueprints
# for now just manually installing the helm chart after creating what I need w/ terraform

locals { 
   flyte_backend_service_account_name = "iam-role-flyte"
}


#-------------------------------------------------
# Flyte S3 buckets
#-------------------------------------------------
resource "aws_s3_bucket" "flyte_metadata_bucket" {
  bucket = "flyte-metadata"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "flyte_metadata_bucket_acl" {
  bucket = aws_s3_bucket.flyte_metadata_bucket.id
  acl = "private"
}

resource "aws_s3_bucket" "flyte_user_data_bucket" {
  bucket = "flyte-user-data"
}

resource "aws_s3_bucket_acl" "flyte_user_data_bucket_acl" {
  bucket = aws_s3_bucket.flyte_user_data_bucket.id
  acl = "private"
}

#-------------------------------------------------
# Flyte RDS
#-------------------------------------------------
# TODO delete this subnet group
resource "aws_db_subnet_group" "flyte_db_subnet_group" {
  name = "flyte-db-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

module "flyte_db_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Complete PostgreSQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.tags
}

resource "aws_db_instance" "flyte_db" {
  allocated_storage = 10
  db_name = "flyteadmin"
  engine = "postgres"
  engine_version = "14.1"
  instance_class = "db.t3.small"

  username="flyteadmin"
  password=var.flyte_db_password

  skip_final_snapshot  = true
  publicly_accessible = false

  db_subnet_group_name = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [ module.flyte_db_security_group.security_group_id ]
}

#-------------------------------------------------
# Flyte Policies
#-------------------------------------------------
resource "aws_iam_policy" "flyte_bucket_policy" {
  name = "flyte-bucket-policy"
  path = "/"
  description = "allow access to flyte spike s3 buckets"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::flyte_metadata",
          "arn:aws:s3:::flyte_user_data"
        ]
      }
    ]
  })
}

#-------------------------------------------------
# Flyte IRSA
#-------------------------------------------------
module "flyte_irsa" {
  source ="../../modules/irsa"

  kubernetes_namespace = "flyte"
  kubernetes_service_account = local.flyte_backend_service_account_name

  eks_cluster_id = module.eks_blueprints.eks_cluster_id
  eks_oidc_provider_arn = module.eks_blueprints.eks_oidc_provider_arn

  irsa_iam_policies = [
    aws_iam_policy.flyte_bucket_policy.arn
  ]
}

#-------------------------------------------------
# Ideally would be done something like this maybe:
#-------------------------------------------------
# module "helm-addon" {
#   source = "../../modules/kubernetes-addons/helm-addon"
#   helm_config   = {
#     name             = "flyte-backend"
#     chart            = "flyteorg/flyte-binary"
#     repository       = "https://flyteorg.github.io/flyte"
#     version          = "v1.3.0"
#     namespace        = "flyte"
#     create_namespace = true
#     values           =  [templatefile("./flyte_values.yaml", {
#       service_account_name = local.flyte_backend_service_account_name
#     })]
#     description      = "flyte-binary helm deploy"
#   }
#   irsa_iam_role_name = local.flyte_backend_service_account_name
# }

output "flyte_rds_host" {
  description = "rds host for flyte"
  value = aws_db_instance.flyte_db.address
}

# Permissions on 'aws/creds/eks-ecr-admin' path
# path "aws/creds/eks-ecr-admin" {
#   capabilities = [ "create", "read", "update", "delete", "list" ]
# }

# Permissions on 'secret/data/aws' path
path "secret/data/aws" {
  capabilities = [ "read" ]
}

# Permissions on 'secret/github/eksctlDeployKey' path
path "secret/data/github/eksctlDeployKey" {
  capabilities = [ "read" ]
}
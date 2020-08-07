# Permissions on 'aws/sts/ecr-push' path
path "aws/sts/ecr-push" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
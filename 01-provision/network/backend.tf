# network/backend.tf — OCI Object Storage remote backend for Terraform state
#
# State is stored in the ods-tf-state bucket created by 00-iam/main.tf.
# This ensures state persists across GitHub Actions runs — no cache dependency.
#
# All sensitive values are injected via -backend-config flags at terraform init
# time by the GitHub Actions workflow, so this file contains no secrets and is
# safe to commit.
#
# To initialise locally:
#   terraform init \
#     -backend-config="address=https://objectstorage.<region>.oraclecloud.com/v1/<namespace>/ods-tf-state/network/terraform.tfstate" \
#     -backend-config="update_method=PUT"

terraform {
  backend "http" {
    # address, update_method, and auth headers injected via -backend-config at init time
  }
}

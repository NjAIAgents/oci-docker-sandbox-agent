# objectstorage/main.tf — Postgres backup bucket
#
# Creates:
#   - oci_objectstorage_bucket.pg_backups                      — "ods-pg-backups" bucket
#   - oci_objectstorage_object_lifecycle_policy.pg_backup_retention — auto-expire after retention_days
#
# Dynamic group + IAM policies (Instance Principal auth + lifecycle service grant)
# are managed in 00-iam/main.tf — they require admin/tenancy-root credentials.

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
}

# ============================================================
# Postgres backup bucket
# ============================================================
resource "oci_objectstorage_bucket" "pg_backups" {
  compartment_id = var.compartment_id
  namespace      = var.object_storage_namespace
  name           = "ods-pg-backups"
  access_type    = "NoPublicAccess"

  versioning = "Disabled"   # backups are write-once; versioning would double storage consumption

  metadata = {
    purpose = "Postgres database backups from ods-instance VM"
  }
}

# ============================================================
# Lifecycle policy — auto-delete backups older than retention_days
# Keeps the 20 GB Always Free Object Storage quota from filling up
# ============================================================
resource "oci_objectstorage_object_lifecycle_policy" "pg_backup_retention" {
  namespace   = var.object_storage_namespace
  bucket      = oci_objectstorage_bucket.pg_backups.name

  rules {
    name        = "expire-old-backups"
    action      = "DELETE"
    is_enabled  = true
    time_amount = var.retention_days
    time_unit   = "DAYS"

    object_name_filter {
      inclusion_prefixes = ["backups/"]
    }
  }
}

# ============================================================
# Outputs
# ============================================================
output "bucket_name" {
  value       = oci_objectstorage_bucket.pg_backups.name
  description = "Object Storage bucket name for Postgres backups."
}

output "namespace" {
  value       = var.object_storage_namespace
  description = "Object Storage namespace. Use in OCI CLI: --namespace <value>"
}

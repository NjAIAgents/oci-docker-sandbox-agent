# objectstorage/main.tf — Postgres backup bucket + Instance Principal IAM
#
# Creates:
#   - oci_objectstorage_bucket.pg_backups     — "ods-pg-backups" bucket
#   - oci_objectstorage_object_lifecycle_policy — auto-expire objects after retention_days
#   - oci_identity_dynamic_group.vm_instances — dynamic group matching all instances in compartment
#   - oci_identity_policy.pg_backup           — allows VM to write objects via Instance Principal
#
# The VM authenticates to Object Storage using Instance Principals (no API key needed).
# After apply, configure the OCI CLI on the VM with:
#   oci setup instance-principal   (or use auth=instance_principal in oci config)

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
# Dynamic group — matches all instances in the compartment
# This is what enables Instance Principal auth on the VM
# ============================================================
resource "oci_identity_dynamic_group" "vm_instances" {
  compartment_id = var.tenancy_ocid   # dynamic groups live at tenancy root
  name           = "ods-vm-instances"
  description    = "All compute instances in the ODS sandbox compartment — for Instance Principal auth"
  matching_rule  = "All {instance.compartment.id = '${var.compartment_id}'}"
}

# ============================================================
# IAM policy — allows VMs in the dynamic group to write backups
# Scoped to the sandbox compartment only
# ============================================================
resource "oci_identity_policy" "pg_backup" {
  compartment_id = var.tenancy_ocid   # policies referencing a compartment must be at tenancy root
  name           = "ods-pg-backup-policy"
  description    = "Allows ods-instance VM to write Postgres backups to ods-pg-backups bucket via Instance Principal"

  statements = [
    "Allow dynamic-group ods-vm-instances to manage objects in compartment id ${var.compartment_id} where target.bucket.name = 'ods-pg-backups'",
    "Allow dynamic-group ods-vm-instances to read buckets in compartment id ${var.compartment_id} where target.bucket.name = 'ods-pg-backups'",
  ]
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

output "dynamic_group_name" {
  value       = oci_identity_dynamic_group.vm_instances.name
  description = "Dynamic group name used for Instance Principal auth."
}

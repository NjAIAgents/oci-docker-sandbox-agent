# objectstorage/main.tf — Postgres backup bucket
#
# Creates:
#   - oci_objectstorage_bucket.pg_backups                          — "ods-pg-backups" bucket
#   - oci_objectstorage_object_lifecycle_policy.pg_backup_retention — auto-expire after retention_days
#   - oci_ons_notification_topic.bucket_alerts                     — email notification topic
#   - oci_ons_subscription.bucket_alerts_email                     — subscribes notification_email
#   - oci_monitoring_alarm.bucket_warning                          — fires at 16 GB
#   - oci_monitoring_alarm.bucket_urgent                           — fires at 18 GB
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
# Lifecycle policy — delete after retention_days
# Archive tiering is NOT used: Always Free gives 20 GB total shared across
# all tiers (Standard + Infrequent Access + Archive combined), so tiering
# provides no additional free quota.
# ============================================================
resource "oci_objectstorage_object_lifecycle_policy" "pg_backup_retention" {
  namespace   = var.object_storage_namespace
  bucket      = oci_objectstorage_bucket.pg_backups.name

  rules {
    name        = "delete-old-backups"
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
# Notification topic — receives alarm events and fans out to email
# ============================================================
resource "oci_ons_notification_topic" "bucket_alerts" {
  compartment_id = var.compartment_id
  name           = "ods-pg-backup-alerts"
  description    = "Alerts for ods-pg-backups bucket size thresholds"
}

resource "oci_ons_subscription" "bucket_alerts_email" {
  compartment_id = var.compartment_id
  topic_id       = oci_ons_notification_topic.bucket_alerts.id
  protocol       = "EMAIL"
  endpoint       = var.notification_email
}

# ============================================================
# Alarms — OCI Monitoring on ObjectStorage StorageBytes metric
# StorageBytes is reported in bytes; thresholds below are in bytes:
#   16 GB = 17,179,869,184
#   18 GB = 19,327,352,832
# ============================================================
# ============================================================
# Alarms — watch total bucket storage (Standard covers all tiers in OCI metrics)
# Always Free limit: 20 GB combined across all tiers
# ============================================================
resource "oci_monitoring_alarm" "bucket_warning" {
  compartment_id        = var.compartment_id
  display_name          = "ods-pg-backups-warning-16gb"
  is_enabled            = true
  metric_compartment_id = var.compartment_id

  namespace   = "oci_objectstorage"
  query       = "StorageBytes[1d]{bucketName = \"ods-pg-backups\"}.max() > ${16 * 1024 * 1024 * 1024}"
  severity    = "WARNING"
  body        = "ods-pg-backups has exceeded 16 GB. Always Free limit is 20 GB total across all tiers. Review backup size or reduce retention_days."

  destinations     = [oci_ons_notification_topic.bucket_alerts.id]
  pending_duration = "PT5M"
  is_notifications_per_metric_dimension_enabled = false
}

resource "oci_monitoring_alarm" "bucket_urgent" {
  compartment_id        = var.compartment_id
  display_name          = "ods-pg-backups-urgent-18gb"
  is_enabled            = true
  metric_compartment_id = var.compartment_id

  namespace   = "oci_objectstorage"
  query       = "StorageBytes[1d]{bucketName = \"ods-pg-backups\"}.max() > ${18 * 1024 * 1024 * 1024}"
  severity    = "CRITICAL"
  body        = "URGENT: ods-pg-backups has exceeded 18 GB. Always Free limit is 20 GB total. Immediate action required to avoid overage charges."

  destinations     = [oci_ons_notification_topic.bucket_alerts.id]
  pending_duration = "PT5M"
  is_notifications_per_metric_dimension_enabled = false
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

output "notification_topic_id" {
  value       = oci_ons_notification_topic.bucket_alerts.id
  description = "ONS topic OCID receiving bucket size alerts. Check email for subscription confirmation."
}

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
# Lifecycle policy
#   Rule 1: Move to Archive tier after 7 days  (Archive tier is free, separate 20 GB quota)
#   Rule 2: Delete after retention_days (30)   (Archive minimum retention is 90 days —
#                                               OCI won't error but objects < 90 days incur
#                                               an early-delete fee on paid tenancies; on
#                                               Always Free this is not charged)
# ============================================================
resource "oci_objectstorage_object_lifecycle_policy" "pg_backup_retention" {
  namespace   = var.object_storage_namespace
  bucket      = oci_objectstorage_bucket.pg_backups.name

  rules {
    name        = "tier-to-archive"
    action      = "ARCHIVE"
    is_enabled  = true
    time_amount = 7
    time_unit   = "DAYS"

    object_name_filter {
      inclusion_prefixes = ["backups/"]
    }
  }

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
# Standard tier alarms (recent 7-day backups)
resource "oci_monitoring_alarm" "standard_warning" {
  compartment_id        = var.compartment_id
  display_name          = "ods-pg-backups-standard-warning-16gb"
  is_enabled            = true
  metric_compartment_id = var.compartment_id

  namespace   = "oci_objectstorage"
  query       = "StorageBytes[1d]{bucketName = \"ods-pg-backups\"}.max() > ${16 * 1024 * 1024 * 1024}"
  severity    = "WARNING"
  body        = "ods-pg-backups Standard tier has exceeded 16 GB (Always Free limit: 20 GB). Recent backups are growing — check backup size or reduce daily frequency."

  destinations     = [oci_ons_notification_topic.bucket_alerts.id]
  pending_duration = "PT5M"
  is_notifications_per_metric_dimension_enabled = false
}

resource "oci_monitoring_alarm" "standard_urgent" {
  compartment_id        = var.compartment_id
  display_name          = "ods-pg-backups-standard-urgent-18gb"
  is_enabled            = true
  metric_compartment_id = var.compartment_id

  namespace   = "oci_objectstorage"
  query       = "StorageBytes[1d]{bucketName = \"ods-pg-backups\"}.max() > ${18 * 1024 * 1024 * 1024}"
  severity    = "CRITICAL"
  body        = "URGENT: ods-pg-backups Standard tier has exceeded 18 GB (Always Free limit: 20 GB). Immediate action required to avoid overage charges."

  destinations     = [oci_ons_notification_topic.bucket_alerts.id]
  pending_duration = "PT5M"
  is_notifications_per_metric_dimension_enabled = false
}

# Archive tier alarms (backups older than 7 days)
resource "oci_monitoring_alarm" "archive_warning" {
  compartment_id        = var.compartment_id
  display_name          = "ods-pg-backups-archive-warning-16gb"
  is_enabled            = true
  metric_compartment_id = var.compartment_id

  namespace   = "oci_objectstorage"
  query       = "ArchiveStorageBytes[1d]{bucketName = \"ods-pg-backups\"}.max() > ${16 * 1024 * 1024 * 1024}"
  severity    = "WARNING"
  body        = "ods-pg-backups Archive tier has exceeded 16 GB (Always Free limit: 20 GB). Consider reducing retention_days."

  destinations     = [oci_ons_notification_topic.bucket_alerts.id]
  pending_duration = "PT5M"
  is_notifications_per_metric_dimension_enabled = false
}

resource "oci_monitoring_alarm" "archive_urgent" {
  compartment_id        = var.compartment_id
  display_name          = "ods-pg-backups-archive-urgent-18gb"
  is_enabled            = true
  metric_compartment_id = var.compartment_id

  namespace   = "oci_objectstorage"
  query       = "ArchiveStorageBytes[1d]{bucketName = \"ods-pg-backups\"}.max() > ${18 * 1024 * 1024 * 1024}"
  severity    = "CRITICAL"
  body        = "URGENT: ods-pg-backups Archive tier has exceeded 18 GB (Always Free limit: 20 GB). Immediate action required to avoid overage charges."

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

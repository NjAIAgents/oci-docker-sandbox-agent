# objectstorage/variable.tf — Variables for the objectstorage module

variable "tenancy_ocid" {
  type        = string
  description = "OCI Tenancy OCID. Required for dynamic group and policy resources (tenancy-root)."
}

variable "compartment_id" {
  type        = string
  description = "Compartment OCID to create the bucket in. Matches the sandbox compartment used by instance and network modules."
}

variable "region" {
  type        = string
  description = "OCI region identifier (e.g. us-chicago-1)."
}

variable "object_storage_namespace" {
  type        = string
  description = "OCI Object Storage namespace for your tenancy. Run: oci os ns get"
}

variable "retention_days" {
  type        = number
  description = "Number of days to retain backup objects before auto-deletion. 30 is a safe default for the 20 GB Always Free quota."
  default     = 30
}

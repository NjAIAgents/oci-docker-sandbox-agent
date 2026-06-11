# network/main.tf — OCI networking resources for the ODS sandbox
#
# Resources created:
#   - VCN (10.0.0.0/16)
#   - Internet Gateway
#   - Route Table (default route via IGW)
#   - Security List (ingress SSH from your current public IP only + egress all)
#   - Public Subnet (10.0.1.0/24)
#
# SSH is restricted to the machine running terraform apply.
# Run update-ssh-allowlist.sh whenever your public IP changes.

terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

# Fetches the public IP of the machine running terraform apply
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
}

# ============================================================
# VCN
# ============================================================
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_block     = "10.0.0.0/16"
  display_name   = "ods-vcn"
  dns_label      = "odsvcn"
}

# ============================================================
# Internet Gateway
# ============================================================
resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "ods-igw"
  enabled        = true
}

# ============================================================
# Route Table
# ============================================================
resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "ods-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# ============================================================
# Security List — ingress SSH + egress all
# ============================================================
resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "ods-sl"

  ingress_security_rules {
    description = "SSH — current machine only (${trimspace(data.http.my_ip.response_body)}/32)"
    protocol    = "6"   # TCP
    source      = "${trimspace(data.http.my_ip.response_body)}/32"
    stateless   = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    description = "All outbound traffic"
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

# ============================================================
# Subnet — public, attached to route table and security list
# ============================================================
resource "oci_core_subnet" "main" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "ods-subnet"
  dns_label                  = "odssubnet"
  route_table_id             = oci_core_route_table.main.id
  security_list_ids          = [oci_core_security_list.main.id]
  prohibit_public_ip_on_vnic = false
}

# ============================================================
# Outputs — consumed by provision.sh and the instance module
# ============================================================
output "subnet_id" {
  value       = oci_core_subnet.main.id
  description = "OCID of the public subnet. Passed to the instance module by provision.sh."
}

output "vcn_id" {
  value       = oci_core_vcn.main.id
  description = "OCID of the VCN."
}

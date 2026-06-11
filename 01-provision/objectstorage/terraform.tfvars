# objectstorage/terraform.tfvars — Values for the objectstorage module
#
# tenancy_ocid is passed dynamically by provision.sh via -var flag (same as other modules)
# Fill in compartment_id and region to match your network/terraform.tfvars

compartment_id = "ocid1.compartment.oc1..aaaaaaaay6dkfa65mx4wzqpfzcp4czrx4icfz3arr4hyiqzn4a2acjds4zsa"
region         = "us-chicago-1"
retention_days = 30

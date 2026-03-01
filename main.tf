resource "oci_identity_compartment" "this" {
  compartment_id = var.tenancy_ocid
  description    = var.name
  name           = replace(var.name, " ", "-")
  enable_delete  = true
}

resource "oci_core_vcn" "this" {
  compartment_id = oci_identity_compartment.this.id
  cidr_block     = "10.0.0.0/16"  # Adjust the CIDR block accordingly
  display_name   = "vcn"
  dns_label      = "vcn"
}

resource "oci_core_subnet" "this" {
  compartment_id = oci_identity_compartment.this.id
  vcn_id         = oci_core_vcn.this.id
  cidr_block     = "10.0.0.0/24" # Adjust the CIDR block accordingly
  display_name   = "subnet"
  dns_label      = "subnet"
}


data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

resource "random_shuffle" "this" {
  input        = data.oci_identity_availability_domains.this.availability_domains[*].name
  result_count = 1
}

data "cloudinit_config" "this" {
  for_each = local.instance
  part {
    content      = yamlencode(each.value.user_data)
    content_type = "text/cloud-config"
  }
}

resource "oci_core_instance" "oracle" {
  count               = 2
  availability_domain = random_shuffle.this.result.0
  compartment_id      = oci_identity_compartment.this.id
  shape               = local.instance.arm.shape
  display_name        = "Ubuntu ARM ${count.index + 1}"
  preserve_boot_volume = false
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.cloudinit_config.this["arm"].rendered
  }
  agent_config {
    are_all_plugins_disabled = true
    is_management_disabled   = true
    is_monitoring_disabled   = true
  }
  create_vnic_details {
    assign_public_ip = false
    display_name     = "Ubuntu ARM ${count.index + 1}"
    hostname_label   = "ubuntu-arm-${count.index + 1}"
    subnet_id        = oci_core_subnet.this.id
  }
  shape_config {
    memory_in_gbs = 6
    ocpus         = 2
  }
  source_details {
    source_id               = local.instance.arm.image_ocid
    source_type             = "image"
    boot_volume_size_in_gbs = 100
  }
  lifecycle {
    ignore_changes = [source_details.0.source_id]
  }
}

resource "oci_core_volume_backup_policy" "this" {
  compartment_id = oci_identity_compartment.this.id
  display_name   = "Daily"
  schedules {
    backup_type       = "INCREMENTAL"
    hour_of_day       = 0
    offset_type       = "STRUCTURED"
    period            = "ONE_DAY"
    retention_seconds = 86400
    time_zone         = "REGIONAL_DATA_CENTER_TIME"
  }
}

resource "oci_core_volume_backup_policy_assignment" "this" {
  count     = 2
  asset_id  = oci_core_instance.oracle[count.index].boot_volume_id
  policy_id = oci_core_volume_backup_policy.this.id
}
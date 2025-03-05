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

data "oci_core_shapes" "this" {
  for_each = toset(data.oci_identity_availability_domains.this.availability_domains[*].name)
  compartment_id = oci_identity_compartment.this.id
  availability_domain = each.key
}

data "cloudinit_config" "this" {
  for_each = local.instance
  part {
    content      = yamlencode(each.value.user_data)
    content_type = "text/cloud-config"
  }
}

data "oci_core_images" "this" {
  for_each = local.instance
  compartment_id = oci_identity_compartment.this.id
  operating_system = each.value.operating_system
  shape            = each.value.shape
  sort_by          = "DISPLAYNAME"
  sort_order       = "DESC"
  state            = "AVAILABLE"
}

resource "oci_core_instance" "ubuntu" {
  count              = 2
  availability_domain = one([for m in data.oci_core_shapes.this : m.availability_domain if contains(m.shapes[*].name, local.instance.ubuntu.shape)])
  compartment_id     = oci_identity_compartment.this.id
  shape              = local.instance.ubuntu.shape
  display_name       = "Ubuntu ${count.index + 1}"
  preserve_boot_volume = false
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.cloudinit_config.this["ubuntu"].rendered
  }
  agent_config {
    are_all_plugins_disabled = true
    is_management_disabled   = true
    is_monitoring_disabled   = true
  }
  create_vnic_details {
    display_name   = "Ubuntu ${count.index + 1}"
    hostname_label = "ubuntu-${count.index + 1}"
    subnet_id      = oci_core_subnet.this.id
  }
  source_details {
    source_id               = data.oci_core_images.this["ubuntu"].images.0.id
    source_type             = "image"
    boot_volume_size_in_gbs = 50
  }
  lifecycle {
    ignore_changes = [source_details.0.source_id]
  }
}

resource "oci_core_instance" "oracle" {
  availability_domain = random_shuffle.this.result.0
  compartment_id      = oci_identity_compartment.this.id
  shape               = local.instance.oracle.shape
  display_name        = "Oracle Linux"
  preserve_boot_volume = false
  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = data.cloudinit_config.this["oracle"].rendered
  }
  agent_config {
    are_all_plugins_disabled = true
    is_management_disabled   = true
    is_monitoring_disabled   = true
  }
  create_vnic_details {
    assign_public_ip = false
    display_name     = "Oracle Linux"
    hostname_label   = "oracle-linux"
    subnet_id        = oci_core_subnet.this.id
  }
  shape_config {
    memory_in_gbs = 24
    ocpus         = 4
  }
  source_details {
    source_id               = data.oci_core_images.this["oracle"].images.0.id
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
  count = 3
  asset_id = count.index < 2 ? oci_core_instance.ubuntu[count.index].boot_volume_id : oci_core_instance.oracle.boot_volume_id
  policy_id = oci_core_volume_backup_policy.this.id
}
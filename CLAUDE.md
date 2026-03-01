# CLAUDE.md — oci-terraform-cluster

Terraform configuration that provisions OCI ARM compute instances at maximum free-tier capacity, with daily backup policies.

## Files

| File | Purpose |
|------|---------|
| `main.tf` | All resources: compartment, VCN, subnet, instances, backup policy |
| `variables.tf` | Input variables (tenancy, region, name, CIDR, SSH key) |
| `locals.tf` | Instance shape, image OCID, and cloud-init definitions |
| `schema.yaml` | OCI Resource Manager GUI variable layout |

## Resources Provisioned

### Compute Instances
| Name | Shape | OS | OCPUs | RAM | Boot Vol |
|------|-------|----|-------|-----|----------|
| Ubuntu ARM 1 & 2 | `VM.Standard.A1.Flex` | Ubuntu 24.04 LTS (aarch64) | 2 | 6 GB | 100 GB |

- Both instances: random AD selection; no public IP assigned
- Image hardcoded: `Canonical-Ubuntu-24.04-aarch64-2026.01.29-0`
  - OCID: `ocid1.image.oc1.ca-montreal-1.aaaaaaaa7f73hpjf2wa62jpmqyvrofoyjcudltupmftsjmri72xkgqghykla`
- All agents disabled (`are_all_plugins_disabled = true`)
- Free-tier usage: 4 OCPUs / 12 GB RAM (of 4 OCPU / 24 GB available)

### Cloud-init (via `locals.tf`)
- **Ubuntu ARM**: removes AppArmor (`apt-get remove apparmor`)

### Network (inline, not shared with oci-terraform-network)
- Compartment: created by this module (`oci_identity_compartment`)
- VCN: `10.0.0.0/16`
- Subnet: `10.0.0.0/24`

### Backup Policy
- Name: `Daily`
- Type: `INCREMENTAL`, runs at midnight, retention 24 hours
- Assigned to: boot volumes of both instances

## Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `tenancy_ocid` | Yes | — | Tenancy OCID |
| `region` | Yes | — | OCI region |
| `ssh_public_key` | Yes | — | SSH public key for instance access |
| `name` | No | `OCI Free Compute Maximal` | Display name for compartment/resources |
| `cidr_block` | No | `null` | Override VCN CIDR (must be valid, prefix ≤ /30) |

## Commands

```bash
terraform init     # Initialize providers (locks OCI provider v6.28.0)
terraform plan     # Preview changes
terraform apply    # Deploy all resources
terraform destroy  # Tear down everything including compartment
```

## Notes

- `source_details.source_id` is ignored on lifecycle updates — image changes won't replace instances
- `preserve_boot_volume = false` — boot volumes are deleted with instances
- OCI provider credentials come from environment or `~/.oci/config` (no explicit provider block)
- `schema.yaml` is used only when deploying via the OCI Resource Manager console

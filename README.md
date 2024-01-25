[![Release][release-image]][release] [![CI][ci-image]][ci] [![License][license-image]][license] [![Registry][registry-image]][registry] [![Source][source-image]][source]

# terraform-google-iglu-server-ce

A Terraform module which deploys a Snowplow Iglu Server application on Google running on top of Compute Engine.  If you want to use a custom image for this deployment you will need to ensure it is based on top of Ubuntu 20.04.

## Telemetry

This module by default collects and forwards telemetry information to Snowplow to understand how our applications are being used.  No identifying information about your sub-account or account fingerprints are ever forwarded to us - it is very simple information about what modules and applications are deployed and active.

If you wish to subscribe to our mailing list for updates to these modules or security advisories please set the `user_provided_id` variable to include a valid email address which we can reach you at.

### How do I disable it?

To disable telemetry simply set variable `telemetry_enabled = false`.

### What are you collecting?

For details on what information is collected please see this module: https://github.com/snowplow-devops/terraform-snowplow-telemetry

## Usage

The Iglu Server stack requires a Load Balancer and a Postgres instance to save information into for its backend.  Here we are using several managed modules to facilitate this requirement but you can also sub in your own Postgres Host and Load Balancer if you prefer to do so.

```hcl
locals {
  iglu_db_name     = "iglu"
  iglu_db_username = "iglu"

  # Keep this secret!!
  iglu_db_password = "Hell0W0rld!"

  # Used for API actions on the Iglu Server. Keep this secret!!
  iglu_super_api_key = "2f48ad70-b70c-4f58-af3b-f19d8b7706e1"
}

module "iglu_db" {
  source  = "snowplow-devops/cloud-sql/google"
  version = "0.3.0"

  name = "iglu-db"

  region      = local.region
  db_name     = local.iglu_db_name
  db_username = local.iglu_db_username
  db_password = local.iglu_db_password
}

module "iglu_server" {
  source  = "snowplow-devops/iglu-server-ce/google"

  accept_limited_use_license = true

  name = "iglu-server"

  project_id = "<project_id>"

  network    = var.network
  subnetwork = var.subnetwork
  region     = var.region

  ssh_ip_allowlist = ["0.0.0.0/0"]
  ssh_key_pairs    = []

  db_instance_name = module.iglu_db.connection_name
  db_port          = module.iglu_db.port
  db_name          = local.iglu_db_name
  db_username      = local.iglu_db_username
  db_password      = local.iglu_db_password
  super_api_key    = local.iglu_super_api_key
}

module "iglu_lb" {
  source  = "snowplow-devops/lb/google"
  version = "0.3.0"

  name = "iglu-lb"

  instance_group_named_port_http = module.iglu_server.named_port_http
  instance_group_url             = module.iglu_server.instance_group_url
  health_check_self_link         = module.iglu_server.health_check_self_link
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 3.90 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 3.90 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_service"></a> [service](#module\_service) | snowplow-devops/service-ce/google | 0.1.0 |
| <a name="module_telemetry"></a> [telemetry](#module\_telemetry) | snowplow-devops/telemetry/snowplow | 0.5.0 |

## Resources

| Name | Type |
|------|------|
| [google_compute_firewall.egress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.ingress](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.ingress_ssh](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_project_iam_member.sa_cloud_sql_client](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.sa_logging_log_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | The name of the database to connect to | `string` | n/a | yes |
| <a name="input_db_password"></a> [db\_password](#input\_db\_password) | The password to use to connect to the database | `string` | n/a | yes |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | The port the database is running on | `number` | n/a | yes |
| <a name="input_db_username"></a> [db\_username](#input\_db\_username) | The username to use to connect to the database | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | A name which will be pre-pended to the resources created | `string` | n/a | yes |
| <a name="input_network"></a> [network](#input\_network) | The name of the network to deploy within | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The project ID in which the stack is being deployed | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The name of the region to deploy within | `string` | n/a | yes |
| <a name="input_super_api_key"></a> [super\_api\_key](#input\_super\_api\_key) | A UUIDv4 string to use as the master API key for Iglu Server management | `string` | n/a | yes |
| <a name="input_accept_limited_use_license"></a> [accept\_limited\_use\_license](#input\_accept\_limited\_use\_license) | Acceptance of the SLULA terms (https://docs.snowplow.io/limited-use-license-1.0/) | `bool` | `false` | no |
| <a name="input_app_version"></a> [app\_version](#input\_app\_version) | App version to use. This variable facilitates dev flow, the modules may not work with anything other than the default value. | `string` | `"0.10.0"` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Whether to assign a public ip address to this instance; if false this instance must be behind a Cloud NAT to connect to the internet | `bool` | `true` | no |
| <a name="input_db_host"></a> [db\_host](#input\_db\_host) | The hostname of the database to connect to (Note: if db\_instance\_name is non-empty this setting is ignored) | `string` | `""` | no |
| <a name="input_db_instance_name"></a> [db\_instance\_name](#input\_db\_instance\_name) | The instance name of the CloudSQL instance to connect to (Note: if set db\_host will be ignored and a proxy established instead) | `string` | `""` | no |
| <a name="input_gcp_logs_enabled"></a> [gcp\_logs\_enabled](#input\_gcp\_logs\_enabled) | Whether application logs should be reported to GCP Logging | `bool` | `true` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | The path to bind for health checks | `string` | `"/api/meta/health"` | no |
| <a name="input_ingress_port"></a> [ingress\_port](#input\_ingress\_port) | The port that the iglu server will be bound to and expose over HTTP | `number` | `8080` | no |
| <a name="input_java_opts"></a> [java\_opts](#input\_java\_opts) | Custom JAVA Options | `string` | `"-XX:InitialRAMPercentage=75 -XX:MaxRAMPercentage=75"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | The labels to append to this resource | `map(string)` | `{}` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | The machine type to use | `string` | `"e2-small"` | no |
| <a name="input_patches_allowed"></a> [patches\_allowed](#input\_patches\_allowed) | Whether or not patches are allowed for published Iglu Schemas | `bool` | `true` | no |
| <a name="input_ssh_block_project_keys"></a> [ssh\_block\_project\_keys](#input\_ssh\_block\_project\_keys) | Whether to block project wide SSH keys | `bool` | `true` | no |
| <a name="input_ssh_ip_allowlist"></a> [ssh\_ip\_allowlist](#input\_ssh\_ip\_allowlist) | The list of CIDR ranges to allow SSH traffic from | `list(any)` | <pre>[<br>  "0.0.0.0/0"<br>]</pre> | no |
| <a name="input_ssh_key_pairs"></a> [ssh\_key\_pairs](#input\_ssh\_key\_pairs) | The list of SSH key-pairs to add to the servers | <pre>list(object({<br>    user_name  = string<br>    public_key = string<br>  }))</pre> | `[]` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The name of the sub-network to deploy within; if populated will override the 'network' setting | `string` | `""` | no |
| <a name="input_target_size"></a> [target\_size](#input\_target\_size) | The number of servers to deploy | `number` | `1` | no |
| <a name="input_telemetry_enabled"></a> [telemetry\_enabled](#input\_telemetry\_enabled) | Whether or not to send telemetry information back to Snowplow Analytics Ltd | `bool` | `true` | no |
| <a name="input_ubuntu_20_04_source_image"></a> [ubuntu\_20\_04\_source\_image](#input\_ubuntu\_20\_04\_source\_image) | The source image to use which must be based of of Ubuntu 20.04; by default the latest community version is used | `string` | `""` | no |
| <a name="input_user_provided_id"></a> [user\_provided\_id](#input\_user\_provided\_id) | An optional unique identifier to identify the telemetry events emitted by this stack | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_health_check_id"></a> [health\_check\_id](#output\_health\_check\_id) | Identifier for the health check on the instance group |
| <a name="output_health_check_self_link"></a> [health\_check\_self\_link](#output\_health\_check\_self\_link) | The URL for the health check on the instance group |
| <a name="output_instance_group_url"></a> [instance\_group\_url](#output\_instance\_group\_url) | The full URL of the instance group created by the manager |
| <a name="output_manager_id"></a> [manager\_id](#output\_manager\_id) | Identifier for the instance group manager |
| <a name="output_manager_self_link"></a> [manager\_self\_link](#output\_manager\_self\_link) | The URL for the instance group manager |
| <a name="output_named_port_http"></a> [named\_port\_http](#output\_named\_port\_http) | The name of the port exposed by the instance group |
| <a name="output_named_port_value"></a> [named\_port\_value](#output\_named\_port\_value) | The named port value (e.g. 8080) |

# Copyright and license

Copyright 2021-present Snowplow Analytics Ltd.

Licensed under the [Snowplow Limited Use License Agreement][license]. _(If you are uncertain how it applies to your use case, check our answers to [frequently asked questions][license-faq].)_

[release]: https://github.com/snowplow-devops/terraform-google-iglu-server-ce/releases/latest
[release-image]: https://img.shields.io/github/v/release/snowplow-devops/terraform-google-iglu-server-ce

[ci]: https://github.com/snowplow-devops/terraform-google-iglu-server-ce/actions?query=workflow%3Aci
[ci-image]: https://github.com/snowplow-devops/terraform-google-iglu-server-ce/workflows/ci/badge.svg

[license]: https://docs.snowplow.io/limited-use-license-1.0/
[license-image]: https://img.shields.io/badge/license-Snowplow--Limited--Use-blue.svg?style=flat
[license-faq]: https://docs.snowplow.io/docs/contributing/limited-use-license-faq/

[registry]: https://registry.terraform.io/modules/snowplow-devops/iglu-server-ce/google/latest
[registry-image]: https://img.shields.io/static/v1?label=Terraform&message=Registry&color=7B42BC&logo=terraform

[source]: https://github.com/snowplow-incubator/iglu-server
[source-image]: https://img.shields.io/static/v1?label=Snowplow&message=Iglu%20Server&color=0E9BA4&logo=GitHub

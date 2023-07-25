locals {
  module_name    = "iglu-server-ce"
  module_version = "0.3.2"

  app_name    = "iglu-server"
  app_version = var.app_version

  local_labels = {
    name           = var.name
    app_name       = local.app_name
    app_version    = replace(local.app_version, ".", "-")
    module_name    = local.module_name
    module_version = replace(local.module_version, ".", "-")
  }

  labels = merge(
    var.labels,
    local.local_labels
  )

  named_port_http = "http"
}

module "telemetry" {
  source  = "snowplow-devops/telemetry/snowplow"
  version = "0.5.0"

  count = var.telemetry_enabled ? 1 : 0

  user_provided_id = var.user_provided_id
  cloud            = "GCP"
  region           = var.region
  app_name         = local.app_name
  app_version      = local.app_version
  module_name      = local.module_name
  module_version   = local.module_version
}

# --- IAM: Service Account setup

resource "google_service_account" "sa" {
  account_id   = var.name
  display_name = "Snowplow Iglu Server service account - ${var.name}"
}

resource "google_project_iam_member" "sa_logging_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_project_iam_member" "sa_cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

# --- CE: Firewall rules

resource "google_compute_firewall" "ingress_ssh" {
  name = "${var.name}-ssh-in"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_ip_allowlist
}

# Needed to allow Health Checks and External Load Balancing services access to
# our server group.
#
# https://cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges
resource "google_compute_firewall" "ingress" {
  name = "${var.name}-traffic-in"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["${var.ingress_port}"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
}

resource "google_compute_firewall" "egress" {
  name = "${var.name}-traffic-out"

  network     = var.network
  target_tags = [var.name]

  allow {
    protocol = "tcp"
    ports    = ["80", "443", var.db_port]
  }

  allow {
    protocol = "udp"
    ports    = ["123"]
  }

  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]
}

# --- CE: Instance group setup

locals {
  # Note: If we are provided a valid DB Instance Name leverage CloudSQL proxy
  db_host = var.db_instance_name == "" ? var.db_host : "127.0.0.1"

  iglu_server_hocon = templatefile("${path.module}/templates/config.hocon.tmpl", {
    port            = var.ingress_port
    db_host         = local.db_host
    db_port         = var.db_port
    db_name         = var.db_name
    db_username     = var.db_username
    db_password     = var.db_password
    patches_allowed = var.patches_allowed
    super_api_key   = lower(var.super_api_key)
  })

  startup_script = templatefile("${path.module}/templates/startup-script.sh.tmpl", {
    port        = var.ingress_port
    config_b64  = base64encode(local.iglu_server_hocon)
    version     = local.app_version
    db_host     = local.db_host
    db_port     = var.db_port
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password

    db_instance_name        = var.db_instance_name
    cloud_sql_proxy_enabled = var.db_instance_name != ""

    telemetry_script = join("", module.telemetry.*.gcp_ubuntu_20_04_user_data)

    gcp_logs_enabled = var.gcp_logs_enabled

    java_opts = var.java_opts
  })
}

module "service" {
  source  = "snowplow-devops/service-ce/google"
  version = "0.1.0"

  user_supplied_script        = local.startup_script
  name                        = var.name
  instance_group_version_name = "${local.app_name}-${local.app_version}"
  labels                      = local.labels

  region     = var.region
  network    = var.network
  subnetwork = var.subnetwork

  ubuntu_20_04_source_image   = var.ubuntu_20_04_source_image
  machine_type                = var.machine_type
  target_size                 = var.target_size
  ssh_block_project_keys      = var.ssh_block_project_keys
  ssh_key_pairs               = var.ssh_key_pairs
  service_account_email       = google_service_account.sa.email
  associate_public_ip_address = var.associate_public_ip_address

  named_port_http   = local.named_port_http
  ingress_port      = var.ingress_port
  health_check_path = var.health_check_path

  depends_on = [
    google_compute_firewall.ingress
  ]
}

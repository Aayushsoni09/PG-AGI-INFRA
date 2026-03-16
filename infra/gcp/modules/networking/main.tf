# ──────────────────────────────────────────
# VPC
# Custom VPC — Cloud Run will connect to this
# via Serverless VPC Connector
# ──────────────────────────────────────────
resource "google_compute_network" "main" {
  name                    = "${var.project_id}-${var.environment}-vpc"
  auto_create_subnetworks = false  # manual subnet control
  project                 = var.project_id
}

# ──────────────────────────────────────────
# SUBNET
# Private subnet for VPC connector
# ──────────────────────────────────────────
resource "google_compute_subnetwork" "main" {
  name          = "${var.project_id}-${var.environment}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
  project       = var.project_id

  private_ip_google_access = true  # allows private access to Google APIs
}

# ──────────────────────────────────────────
# CLOUD ROUTER
# Required for Cloud NAT
# ──────────────────────────────────────────
resource "google_compute_router" "main" {
  name    = "${var.project_id}-${var.environment}-router"
  region  = var.region
  network = google_compute_network.main.id
  project = var.project_id
}

# ──────────────────────────────────────────
# CLOUD NAT
# Allows Cloud Run to reach internet
# (pull images from Artifact Registry, etc.)
# Much cheaper than AWS NAT Gateway
# ──────────────────────────────────────────
resource "google_compute_router_nat" "main" {
  name                               = "${var.project_id}-${var.environment}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}

# ──────────────────────────────────────────
# SERVERLESS VPC CONNECTOR
# Bridges Cloud Run (serverless) to VPC
# Cloud Run is serverless by nature — it
# doesn't live in a subnet like ECS tasks do
# This connector lets Cloud Run services
# communicate within the VPC
# ──────────────────────────────────────────
resource "google_vpc_access_connector" "main" {
  name          = "${var.environment}-connector"
  region        = var.region
  project       = var.project_id
  network       = google_compute_network.main.name
  ip_cidr_range = var.connector_cidr  # must not overlap with subnet

  min_instances = 2
  max_instances = var.connector_max_instances  # dev: 3, prod: 10

  machine_type = var.connector_machine_type  # dev: e2-micro, prod: e2-standard-4
}

# ──────────────────────────────────────────
# FIREWALL RULES
# Allow internal VPC traffic
# Block all external direct access
# ──────────────────────────────────────────
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.project_id}-${var.environment}-allow-internal"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.subnet_cidr, var.connector_cidr]
  description   = "Allow internal VPC traffic"
}

resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.project_id}-${var.environment}-allow-health-checks"
  network = google_compute_network.main.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8000", "3000"]
  }

  # Google's health check IP ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  description   = "Allow Google health checks"
}

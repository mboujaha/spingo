variable "gcp_region" {
  description = "GCP region, e.g. us-east1"
  default     = "us-east1"
}

variable "gcp_project" {
  description = "GCP project name"
  default     = "np-platforms-cd-thd"
}

variable "service_account_name" {
  description = "spinnaker service account to run on halyard vm"
  default     = "spinnaker"
}

variable vault_address {
  type    = "string"
  default = "https://vault.ioq1.homedepot.com:10231"
}

variable terraform_account {
  type    = "string"
  default = "terraform-account"
}

provider "vault" {
  address = "${var.vault_address}"
}

data "vault_generic_secret" "terraform-account" {
  path = "secret/${var.terraform_account}"
}

resource "google_service_account" "service_account" {
  display_name = "${var.service_account_name}"
  account_id   = "${var.service_account_name}"
}

resource "google_project_iam_member" "storage_admin" {
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "clusterAdmin" {
  role   = "roles/container.clusterAdmin"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_project_iam_member" "serviceAccountUser" {
  role   = "roles/iam.serviceAccountUser"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

provider "google" {
  credentials = "${data.vault_generic_secret.terraform-account.data[var.gcp_project]}"
  project     = "${var.gcp_project}"
  region      = "${var.gcp_region}"
}

resource "google_compute_instance" "halyard-spin-vm-grueld" {
  count                     = 1                       // Adjust as desired
  name                      = "halyard-thd-spinnaker"
  machine_type              = "n1-standard-4"         // smallest (CPU &amp; RAM) available instance
  zone                      = "${var.gcp_region}-c"   // yields "europe-west1-d" as setup previously. Places your VM in Europe
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1604-lts"
    }
  }

  // Local SSD disk
  scratch_disk {}

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP - leaving this block empty will generate a new external IP and assign it to the machine
    }
  }

  metadata_startup_script = "echo hi > /test.txt"

  service_account {
    email  = "${google_service_account.service_account.email}"
    scopes = ["userinfo-email", "compute-rw", "storage-rw"]
  }
}

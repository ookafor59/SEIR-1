# IMPORTANT:
# The backend bucket must already exist before `terraform init`.
# This preflight check confirms readiness after initialization succeeds.


terraform {
  required_version = ">= 1.5.0"
}

variable "required_terraform_version" {
  description = "Minimum Terraform version"
  type        = string
  default     = "1.5.0"
}

variable "backend_bucket_name" {
  description = "Existing GCS bucket used for Terraform backend"
  type        = string
  default     = "Lizzo-Pics-STorage"
}

variable "expected_gcp_project" {
  description = "Expected active GCP project for the lab"
  type        = string
  default     = "Lizzo-Luvs-You-6969"
}

resource "terraform_data" "preflight_gate" {
  input = {
    required_terraform_version = var.required_terraform_version
    backend_bucket_name        = var.backend_bucket_name
    expected_gcp_project       = var.expected_gcp_project
    always_run                 = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOT
      set -euo pipefail

      REQUIRED_TERRAFORM="${self.input.required_terraform_version}"
      BACKEND_BUCKET="${self.input.backend_bucket_name}"
      EXPECTED_PROJECT="${self.input.expected_gcp_project}"

      version_ge() {
        [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
      }

      echo "========================================="
      echo "Running preflight gate"
      echo "========================================="

      echo ""
      echo "[1/6] Checking Terraform..."
      command -v terraform >/dev/null 2>&1 || {
        echo "❌ Terraform is not installed"
        exit 1
      }

      TF_INSTALLED="$(terraform version | head -n 1 | awk '{print $2}' | sed 's/^v//')"
      version_ge "$REQUIRED_TERRAFORM" "$TF_INSTALLED" || {
        echo "❌ Terraform version $TF_INSTALLED is too old. Required: $REQUIRED_TERRAFORM+"
        exit 1
      }
      echo "✅ Terraform version $TF_INSTALLED is valid"

      echo ""
      echo "[2/6] Checking gcloud..."
      command -v gcloud >/dev/null 2>&1 || {
        echo "❌ gcloud CLI is not installed"
        exit 1
      }
      echo "✅ gcloud is installed"

      echo ""
      echo "[3/6] Checking ADC authentication..."
      gcloud auth application-default print-access-token >/dev/null 2>&1 || {
        echo "❌ ADC is not configured"
        echo "Run: gcloud auth application-default login"
        exit 1
      }
      echo "✅ ADC authentication is working"

      echo ""
      echo "[4/6] Checking Git..."
      command -v git >/dev/null 2>&1 || {
        echo "❌ Git is not installed"
        exit 1
      }
      echo "✅ Git is installed"

      echo ""
      echo "[5/6] Checking kubectl..."
      command -v kubectl >/dev/null 2>&1 || {
        echo "❌ kubectl is not installed"
        exit 1
      }
      echo "✅ kubectl is installed"

      echo ""
      echo "[6/6] Checking backend bucket and project..."
      ACTIVE_PROJECT="$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')"

      [ "$ACTIVE_PROJECT" = "$EXPECTED_PROJECT" ] || {
        echo "❌ Active gcloud project is '$ACTIVE_PROJECT' but expected '$EXPECTED_PROJECT'"
        echo "Run: gcloud config set project $EXPECTED_PROJECT"
        exit 1
      }
      echo "✅ Active gcloud project matches expected project: $ACTIVE_PROJECT"

      gcloud storage buckets describe "gs://$BACKEND_BUCKET" >/dev/null 2>&1 || {
        echo "❌ Backend bucket gs://$BACKEND_BUCKET does not exist or is not accessible"
        echo "Create it before terraform init:"
        echo "gcloud storage buckets create gs://$BACKEND_BUCKET --location=US-CENTRAL1"
        exit 1
      }
      echo "✅ Backend bucket gs://$BACKEND_BUCKET exists"

      echo ""
      echo "🔥 Preflight gate passed. Environment is ready."
    EOT
  }
}

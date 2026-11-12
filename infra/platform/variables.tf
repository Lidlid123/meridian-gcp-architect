variable "project_id" {
  description = "Existing Google Cloud project with billing enabled"
  type        = string
}

variable "region" {
  description = "EU region for the compute, database and regional secrets replicas"
  type        = string
  default     = "europe-west1"
}

variable "project_id" { type = string }
variable "region" {
  type    = string
  default = "europe-west1"
}
variable "state_bucket" {
  description = "Same GCS bucket used by the platform Terraform state"
  type        = string
}
variable "candidate_name" {
  description = "Exact full name you supplied to the recruiter"
  type        = string
}
variable "commit_sha" {
  description = "Actual short SHA of the Git commit used to build this container"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{7,12}$", var.commit_sha))
    error_message = "Set commit_sha to the real 7-12 digit Git commit SHA."
  }
}
variable "reviewer_email" {
  description = "Recruiter email to grant project Viewer; leave blank during development"
  type        = string
  default     = ""
}

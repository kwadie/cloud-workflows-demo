variable "project" {
  type = string
}

variable "compute_region" {
  type = string
}

variable "data_region" {
  type = string
}


variable "terraform_service_account" {
  type = string
}

variable "bq_dataset" {
  type = string
  default = "sandbox"
}


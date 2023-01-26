variable "project" {type = string}

variable "data_region" {
  type = string
}

variable "logging_dataset_name" {
  type = string
}

variable "gcs_audit_bq_log_sink_name" {
  type = string
  default = "gcs_audit_bq_log_sink"
}

variable "workflows_audit_bq_log_sink_name" {
  type = string
  default = "workflows_audit_bq_log_sink"
}

variable "functions_audit_bq_log_sink_name" {
  type = string
  default = "functions_audit_bq_log_sink"
}

variable "gcs_audit_bq_log_sink_buckets_exp" {
  type = list(string)
  description = "List of bucket names (without gs:// prefix) to monitor"
}
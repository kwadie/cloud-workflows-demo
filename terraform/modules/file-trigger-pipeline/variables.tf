variable "project" {
  type = string
}

variable "compute_region" {
  type = string
}

variable "pipeline_name" {
  type = string
}

variable "sa_spark" {
  type = string
}

variable "sa_workflow" {
  type = string
}

variable "sa_function" {
  type = string
}

variable "sa_pubsub" {
  type = string
}

variable "resource_bucket_name" {
  type = string
}

variable "spark_job_path" {
  type = string
}

variable "spark_job_gcs_postfix" {
  type = string
}

variable "workflow_local_path" {
  type = string
}

variable "cloud_function_src_dir" {
  type = string
}

variable "cloud_function_temp_dir" {
  type = string
}

variable "cloud_function_extra_env_variables" {
  type = map(string)
}

variable "data_bucket_name" {
  type = string
}

variable "data_region" {
  type = string
}


variable "topic_name" {
  type = string
}

variable "subscription_name" {
  type = string
}
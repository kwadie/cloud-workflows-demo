#
# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

provider "google" {
  alias  = "impersonation"
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

data "google_service_account_access_token" "default" {
  provider               = google.impersonation
  target_service_account = var.terraform_service_account
  scopes                 = [
    "userinfo-email",
    "cloud-platform"
  ]
  lifetime = "1200s"
}

provider "google" {
  project = var.project
  region  = var.compute_region

  access_token    = data.google_service_account_access_token.default.access_token
  request_timeout = "60s"
}

provider "google-beta" {
  project = var.project
  region  = var.compute_region

  access_token    = data.google_service_account_access_token.default.access_token
  request_timeout = "60s"
}

module "bigquery" {
  source       = "./modules/bigquery"
  data_region  = var.data_region
  dataset_name = var.bq_dataset
  project      = var.project
}

# create a bucket to store spark jobs files
resource "google_storage_bucket" "resources_bucket" {
  name                        = "${var.project}-resources"
  location                    = var.data_region
  force_destroy               = true
  uniform_bucket_level_access = true
}


// reuse this module for N pipelines
module "wordcount-pipeline" {
  source = "./modules/file-trigger-pipeline"

  pipeline_name = "wordcount"

  compute_region = var.compute_region
  data_region = var.data_region
  project = var.project
  resource_bucket_name = google_storage_bucket.resources_bucket.name

  data_bucket_name = "${var.project}-data-wordcount"
  sa_function = "sa-wordcount-function"
  sa_spark = "sa-wordcount-spark"
  sa_workflow = "sa-wordcount-workflow"
  sa_pubsub = "sa-wordcount-pubsub"
  subscription_name = "wordcount-push"
  topic_name = "wordcount-topic"

  spark_job_path = "../spark/wordcount/wordcount.py"
  spark_job_gcs_postfix = "pyspark/jobs/wordcount.py"
  workflow_local_path = "../workflows/spark-serverless-wordcount/pipeline.yaml"
  cloud_function_src_dir = "../functions/wordcount"
  cloud_function_temp_dir = "/tmp/wordcount.zip"

  cloud_function_extra_env_variables = {
    BQ_OUTPUT_TABLE : "${module.bigquery.poc_dataset}.${module.bigquery.word_count_output_table_name}"
    SPARK_TEMP_BUCKET: "${google_storage_bucket.resources_bucket.name}/spark/temp/wordcount/"
  }
}

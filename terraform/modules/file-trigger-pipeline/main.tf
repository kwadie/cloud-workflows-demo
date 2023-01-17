locals {

  default_env_variables = {
    PROJECT : var.project,
    REGION : var.compute_region,
    CLOUD_WORKFLOW_NAME : var.pipeline_name
    PYSPARK_FILE : "gs://${var.resource_bucket_name}/${google_storage_bucket_object.copy_spark_file.name}"
    SPARK_SERVICE_ACCOUNT : google_service_account.sa_spark.email
  }
}

############## Service Accounts #########################

resource "google_service_account" "sa_spark" {
  project      = var.project
  account_id   = var.sa_spark
  display_name = "Runtime SA for Serverless Spark for pipeline ${var.pipeline_name}"
}


resource "google_service_account" "sa_workflow" {
  project      = var.project
  account_id   = var.sa_workflow
  display_name = "Runtime SA for Cloud Workflow for pipeline ${var.pipeline_name}"
}

resource "google_service_account" "sa_function" {
  project      = var.project
  account_id   = var.sa_function
  display_name = "Runtime SA for Cloud Function for pipeline ${var.pipeline_name}"
}

resource "google_service_account" "sa_pubsub" {
  project      = var.project
  account_id   = var.sa_pubsub
  display_name = "Runtime SA for PubSub Push Subscription for pipeline ${var.pipeline_name}"
}


############## Service Accounts Permissions #########################

######## SA workflows permissions

resource "google_project_iam_member" "sa_workflows_roles" {
  project  = var.project
  for_each = toset([
    "roles/dataproc.admin",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.sa_workflow.email}"
}

# sa_workflows must be a serviceAccountUser on sa_spark to submit spark jobs that uses sa_spark as it's service account
resource "google_service_account_iam_member" "sa_workflows_role_sauser_spark" {
  service_account_id = google_service_account.sa_spark.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.sa_workflow.email}"
}


######## SA spark permissions


resource "google_project_iam_member" "sa_spark_roles" {
  project  = var.project
  for_each = toset([
    "roles/dataproc.worker",
    "roles/bigquery.admin",
    "roles/storage.objectViewer",
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.sa_spark.email}"
}

####### SA cloud functions permissions

# functions SA needs to invoke Cloud Workflows
resource "google_project_iam_member" "sa_function_roles" {
  project  = var.project
  for_each = toset([
    "roles/workflows.invoker",
  ])
  role   = each.key
  member = "serviceAccount:${google_service_account.sa_function.email}"
}

####### SA pubsub permissions

# pubsub push subscription needs to use cloud functions v2 sa in order to invoke it
resource "google_service_account_iam_member" "sa_pubsub_sa_user_functions" {
  service_account_id = google_service_account.sa_function.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.sa_pubsub.email}"
}

// pubsub push subscription needs to invoke the underlying Cloud run service of CFv2
resource "google_cloud_run_service_iam_member" "sa_pubsub_invoker" {

  project  = var.project
  location = var.compute_region
  service  = google_cloudfunctions2_function.gcs_functions.service_config[0].service
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.sa_pubsub.email}"
}

##### Spark Job #################################

# copy the spark job from the repo to GCS
# use loops to deploy multiple files
resource "google_storage_bucket_object" "copy_spark_file" {
  name   = var.spark_job_gcs_postfix
  source = var.spark_job_path
  bucket = var.resource_bucket_name
}

##### Cloud Workflow #################################

resource "google_workflows_workflow" "workflow" {
  project         = var.project
  name            = var.pipeline_name
  region          = var.compute_region
  source_contents = file(var.workflow_local_path)
  service_account = google_service_account.sa_workflow.email

}

##### Cloud Function #################################

# Generates an archive of the source code compressed as a .zip file.
data "archive_file" "source" {
  type        = "zip"
  source_dir  = var.cloud_function_src_dir
  output_path = var.cloud_function_temp_dir
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "zip" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files' content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.source.output_md5}.zip"
  bucket = var.resource_bucket_name
}

# Create the Cloud function triggered by a `Finalize` event on the bucket
resource "google_cloudfunctions2_function" "gcs_functions" {
  name     = var.pipeline_name
  project  = var.project
  location = var.compute_region

  build_config {
    runtime     = "python310"
    entry_point = "execute_cloud_workflow"  # Set the entry point
    source {
      storage_source {
        bucket = var.resource_bucket_name
        object = google_storage_bucket_object.zip.name
      }
    }
  }

  service_config {
    max_instance_count               = 3
    min_instance_count               = 1
    available_memory                 = "1Gi"
    timeout_seconds                  = 60
    max_instance_request_concurrency = 80
    available_cpu                    = "2"
    environment_variables            = merge(local.default_env_variables, var.cloud_function_extra_env_variables)
    ingress_settings                 = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision   = true
    service_account_email            = google_service_account.sa_function.email
  }
}

######## Data bucket with PubSub Notifications ###############

# GCS bucket to store data files and trigger notifications on object creation
resource "google_storage_bucket" "data_bucket" {
  name                        = var.data_bucket_name
  location                    = var.data_region
  force_destroy               = true
  uniform_bucket_level_access = true
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic

resource "google_pubsub_topic" "gcs_notification_topic" {
  project = var.project
  name    = var.topic_name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription

resource "google_pubsub_subscription" "gcs_notification_subscription" {
  project = var.project
  name    = var.subscription_name
  topic   = google_pubsub_topic.gcs_notification_topic.name

  # Policy to delete the subscription when in-active
  expiration_policy {
    # Never Expires. Empty to avoid the 31 days expiration.
    ttl = ""
  }

  retry_policy {
    # The minimum delay between consecutive deliveries of a given message
    minimum_backoff = "60s" #
    # The maximum delay between consecutive deliveries of a given message
    maximum_backoff = "600s" # 10 mins
  }

  push_config {
    push_endpoint = google_cloudfunctions2_function.gcs_functions.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.sa_pubsub.email
    }
  }
}

resource "google_storage_notification" "gcs_notification" {
  bucket         = google_storage_bucket.data_bucket.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.gcs_notification_topic.id
  event_types    = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
  depends_on     = [google_pubsub_topic_iam_binding.gcs_pubsub_binding]
}

// Enable notifications by giving the correct IAM permission to the unique service account.
data "google_storage_project_service_account" "gcs_account" {
}

resource "google_pubsub_topic_iam_binding" "gcs_pubsub_binding" {
  topic   = google_pubsub_topic.gcs_notification_topic.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}



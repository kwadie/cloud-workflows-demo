###### 0. Common Tracking Resources #######

locals {
  // Cloud functions log sink will create a BQ table with that name under the hood so make sure that it's an acceptable table name
  cloud_functions_tracker_log = "cloud_functions_tracker_log"
  workflows_log_table = "workflows_googleapis_com_executions_system"
}
resource "google_bigquery_dataset" "logging_dataset" {
  project = var.project
  location = var.data_region
  dataset_id = var.logging_dataset_name
}


###### 1. Tracking files arriving to GCS #########################
resource "google_project_iam_audit_config" "enable_gcs_audit_logs" {
  project = var.project
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_bigquery_table" "gcs_audit_log_table" {
  project = var.project
  dataset_id = google_bigquery_dataset.logging_dataset.dataset_id
  # don't change the name so that cloud logging can find it
  table_id = "cloudaudit_googleapis_com_data_access"

  time_partitioning {
    type = "DAY"
    #expiration_ms = 604800000 # 7 days
  }

  schema = file("modules/monitoring/tables/cloudaudit_googleapis_com_data_access.json")

  deletion_protection = true
}

resource "google_logging_project_sink" "gcs_audit_bq_log_sink" {
  name = var.gcs_audit_bq_log_sink_name
  destination = "bigquery.googleapis.com/projects/${var.project}/datasets/${google_bigquery_dataset.logging_dataset.dataset_id}"
  filter = "resource.type=gcs_bucket resource.labels.bucket_name= (${join("OR", var.gcs_audit_bq_log_sink_buckets_exp)}) logName=projects/${var.project}/logs/cloudaudit.googleapis.com%2Fdata_access protoPayload.methodName=storage.objects.create"
  # Use a unique writer (creates a unique service account used for writing)
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }
  depends_on = [google_bigquery_table.gcs_audit_log_table]
}

# Logging BQ sink must be able to write data to logging table in the dataset
resource "google_bigquery_dataset_iam_member" "gcs_logging_sink_access" {
  dataset_id = google_bigquery_dataset.logging_dataset.dataset_id
  role = "roles/bigquery.dataEditor"
  member = google_logging_project_sink.gcs_audit_bq_log_sink.writer_identity
}

###### 2. Tracking Cloud Function Execution #########################

resource "google_bigquery_table" "functions_log_table" {
  project = var.project
  dataset_id = google_bigquery_dataset.logging_dataset.dataset_id
  # don't change the name so that cloud logging can find it
  table_id = local.cloud_functions_tracker_log

  time_partitioning {
    type = "DAY"
    #expiration_ms = 604800000 # 7 days
  }

  schema = file("modules/monitoring/tables/cloud_functions_tracker_log.json")

  deletion_protection = true
}

resource "google_logging_project_sink" "functions_audit_bq_log_sink" {
  name = var.functions_audit_bq_log_sink_name
  destination = "bigquery.googleapis.com/projects/${var.project}/datasets/${google_bigquery_dataset.logging_dataset.dataset_id}"
  filter = "resource.type=cloud_function logName=projects/${var.project}/logs/${local.cloud_functions_tracker_log}"
  # Use a unique writer (creates a unique service account used for writing)
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }

  depends_on = [google_bigquery_table.functions_log_table]
}

# Logging BQ sink must be able to write data to logging table in the dataset
resource "google_bigquery_dataset_iam_member" "functions_logging_sink_access" {
  dataset_id = google_bigquery_dataset.logging_dataset.dataset_id
  role = "roles/bigquery.dataEditor"
  member = google_logging_project_sink.functions_audit_bq_log_sink.writer_identity
}


###### 3. Tracking Cloud Workflow Execution #########################

resource "google_bigquery_table" "workflows_log_table" {
  project = var.project
  dataset_id = google_bigquery_dataset.logging_dataset.dataset_id
  # don't change the name so that cloud logging can find it
  table_id = "workflows_googleapis_com_executions_system"

  time_partitioning {
    type = "DAY"
    #expiration_ms = 604800000 # 7 days
  }

  schema = file("modules/monitoring/tables/workflows_googleapis_com_executions_system.json")

  deletion_protection = true
}

resource "google_logging_project_sink" "workflows_audit_bq_log_sink" {
  name = var.workflows_audit_bq_log_sink_name
  destination = "bigquery.googleapis.com/projects/${var.project}/datasets/${google_bigquery_dataset.logging_dataset.dataset_id}"
  filter = "resource.type=workflows.googleapis.com/Workflow jsonPayload.@type=type.googleapis.com/google.cloud.workflows.type.ExecutionsSystemLog"
  # Use a unique writer (creates a unique service account used for writing)
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }

  depends_on = [google_bigquery_table.workflows_log_table]
}

# Logging BQ sink must be able to write data to logging table in the dataset
resource "google_bigquery_dataset_iam_member" "workflows_logging_sink_access" {
  dataset_id = google_bigquery_dataset.logging_dataset.dataset_id
  role = "roles/bigquery.dataEditor"
  member = google_logging_project_sink.workflows_audit_bq_log_sink.writer_identity
}

####### 4. Views  ###

resource "google_bigquery_table" "view_functions_tracker" {
  dataset_id = google_bigquery_dataset.logging_dataset.dataset_id
  table_id = "v_functions_tracker"

  deletion_protection = false

  view {
    use_legacy_sql = false
    query = templatefile("modules/monitoring/views/v_functions_tracker.tpl",
      {
        project = var.project
        dataset = google_bigquery_dataset.logging_dataset.dataset_id
        functions_log_table = google_bigquery_table.functions_log_table.table_id
      }
    )
  }
}

resource "google_bigquery_table" "view_workflows_tracker" {
  dataset_id = google_bigquery_dataset.logging_dataset.dataset_id
  table_id = "v_workflows_tracker"

  deletion_protection = false

  view {
    use_legacy_sql = false
    query = templatefile("modules/monitoring/views/v_workflows_tracker.tpl",
      {
        project = var.project
        dataset = google_bigquery_dataset.logging_dataset.dataset_id
        workflows_log_table = google_bigquery_table.workflows_log_table.table_id
      }
    )
  }
}

resource "google_bigquery_table" "view_global_tracker" {
  dataset_id = google_bigquery_dataset.logging_dataset.dataset_id
  table_id = "v_global_tracker"

  deletion_protection = false

  view {
    use_legacy_sql = false
    query = templatefile("modules/monitoring/views/v_global_tracker.tpl",
      {
        project = var.project
        dataset = google_bigquery_dataset.logging_dataset.dataset_id
        v_functions_tracker = google_bigquery_table.view_functions_tracker.table_id
        v_workflows_tracker = google_bigquery_table.view_workflows_tracker.table_id
      }
    )
  }

  depends_on = [google_logging_project_sink.workflows_audit_bq_log_sink]
}



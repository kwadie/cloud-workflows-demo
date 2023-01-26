output "function_uri" {
  value = google_cloudfunctions2_function.gcs_functions.service_config[0].uri
}

output "gcs_data_bucket_name" {
  value = google_storage_bucket.data_bucket.name
}
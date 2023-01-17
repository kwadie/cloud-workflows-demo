output "function_uri" {
  value = google_cloudfunctions2_function.gcs_functions.service_config[0].uri
}
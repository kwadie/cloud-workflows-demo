
output "poc_dataset" {
  value = google_bigquery_dataset.dataset.dataset_id
}

output "word_count_output_table_name" {
  value = google_bigquery_table.word_count_output.table_id
}


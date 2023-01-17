# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_table
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset


######## Datasets #########################################

resource "google_bigquery_dataset" "dataset" {
  project = var.project
  location = var.data_region
  dataset_id = var.dataset_name
}

######## Tables ##########################################

resource "google_bigquery_table" "word_count_output" {
  project = var.project
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id = "word_count_output"

  schema = file("modules/bigquery/schema/word_Count_output.json")

  deletion_protection = true
}

resource "google_bigquery_table" "word_count_aggregate" {
  project = var.project
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id = "word_count_aggregate"

  schema = file("modules/bigquery/schema/word_count_aggregate.json")

  deletion_protection = true
}


resource "google_bigquery_routine" "sproc_aggregate_word_counts" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  routine_id     = "aggregate_word_counts"
  routine_type = "PROCEDURE"
  language = "SQL"
  definition_body = templatefile("modules/bigquery/routines/aggregate_word_counts.sql",
    {
      project = var.project
      dataset = google_bigquery_dataset.dataset.dataset_id
      sproc_name = "aggregate_word_counts"
    }
  )
}
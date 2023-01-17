#!/bin/bash

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

# spark connector has to match the scala version of dataproc runtime
# dataproc runtimes https://cloud.google.com/dataproc-serverless/docs/concepts/versions/spark-runtime-versions
# bigquery connectors https://console.cloud.google.com/storage/browser/spark-lib/bigquery

REGION=<region>

RUN_ID=`date +%Y%m%d-%H%M%S`
gcloud dataproc batches submit pyspark wordcount.py \
    --region=$REGION \
    --batch=word-count-${RUN_ID} \
    --version=2.0 \
    --jars=gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.13-0.27.1.jar \
    --deps-bucket=tempbucket \
    -- "--input_expression=gs://input" "--output_table=sandbox.word_count_output" "--temp_bucket=tempbucket"
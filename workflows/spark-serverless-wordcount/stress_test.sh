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

# use FIFOs as semaphores and use them to ensure that new processes are spawned as soon as possible and that no more than N processes runs at the same time. But it requires more code.

PROJECT_ID=
WORKFLOW_NAME=
REGION=
PYSPARK_FILE="gs://path-to-python-file"
PYSPARK_ARGS="\"--input_expression=gs://pub/shakespeare/rose.txt\", \"--output_table=sandbox.wordcount_output\", , \"--temp_bucket=tempbucket\""
PYSPARK_DEPS="\"gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.13-0.27.1.jar\""
SPARK_SA="spark service account email"

RUN_ID=`date +%Y%m%d-%H%M%S`

task(){

   gcloud workflows run ${WORKFLOW_NAME} \
   --location=${REGION} \
   --data="{\"pyspark_file\": \"${PYSPARK_FILE}\", \"spark_job_args\": [${PYSPARK_ARGS}], \"spark_dep_jars\": [${PYSPARK_DEPS}], \"dataproc_runtime_version\": \"2.0\", \"dataproc_project\": \"${PROJECT_ID}\", \"dataproc_region\": \"${REGION}\", \"spark_job_name_prefix\": \"stress-${RUN_ID}\", \"spark_service_account\": \"${SPARK_SA}\"}";
}

# number of parallel threads to submit jobs from
N=50
(
# number of jobs to submit
for table in {1..10}; do
   ((i=i%N)); ((i++==0)) && wait
   task "${table}" &
done
)


# /*
# * Copyright 2023 Google LLC
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# *     https://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# */

from flask import escape
import functions_framework

# The incoming JSON payload from GCS notifications is in this schema:
# {
#     'message': {
#         'attributes': {
#             'bucketId': 'pipelines-sandbox-data-wordcount',
#             'eventTime': '2023-01-17T08:21:58.360263Z',
#             'eventType': 'OBJECT_FINALIZE',
#             'notificationConfig': 'projects/_/buckets/pipelines-sandbox-data-wordcount/notificationConfigs/1',
#             'objectGeneration': '1673943718273123',
#             'objectId': 'nice-clap.gif',
#             'payloadFormat': 'JSON_API_V1'
#         },
#         'data': 'ewogICJraW5kIjogInN0b3JhZ2Ujb2JqZWN0IiwKICAiaWQiOiAicGlwZWxpbmVzLXNhbmRib3gtZGF0YS13b3JkY291bnQvbmljZS1jbGFwLmdpZi8xNjczOTQzNzE4MjczMTIzIiwKICAic2VsZkxpbmsiOiAiaHR0cHM6Ly93d3cuZ29vZ2xlYXBpcy5jb20vc3RvcmFnZS92MS9iL3BpcGVsaW5lcy1zYW5kYm94LWRhdGEtd29yZGNvdW50L28vbmljZS1jbGFwLmdpZiIsCiAgIm5hbWUiOiAibmljZS1jbGFwLmdpZiIsCiAgImJ1Y2tldCI6ICJwaXBlbGluZXMtc2FuZGJveC1kYXRhLXdvcmRjb3VudCIsCiAgImdlbmVyYXRpb24iOiAiMTY3Mzk0MzcxODI3MzEyMyIsCiAgIm1ldGFnZW5lcmF0aW9uIjogIjEiLAogICJjb250ZW50VHlwZSI6ICJpbWFnZS9naWYiLAogICJ0aW1lQ3JlYXRlZCI6ICIyMDIzLTAxLTE3VDA4OjIxOjU4LjM2MFoiLAogICJ1cGRhdGVkIjogIjIwMjMtMDEtMTdUMDg6MjE6NTguMzYwWiIsCiAgInN0b3JhZ2VDbGFzcyI6ICJTVEFOREFSRCIsCiAgInRpbWVTdG9yYWdlQ2xhc3NVcGRhdGVkIjogIjIwMjMtMDEtMTdUMDg6MjE6NTguMzYwWiIsCiAgInNpemUiOiAiMTEyOTAwMSIsCiAgIm1kNUhhc2giOiAiR0p5T0pJSFovZklxdU9YaFI1aDh6QT09IiwKICAibWVkaWFMaW5rIjogImh0dHBzOi8vc3RvcmFnZS5nb29nbGVhcGlzLmNvbS9kb3dubG9hZC9zdG9yYWdlL3YxL2IvcGlwZWxpbmVzLXNhbmRib3gtZGF0YS13b3JkY291bnQvby9uaWNlLWNsYXAuZ2lmP2dlbmVyYXRpb249MTY3Mzk0MzcxODI3MzEyMyZhbHQ9bWVkaWEiLAogICJjcmMzMmMiOiAiRlV0TkV3PT0iLAogICJldGFnIjogIkNPUEF6cVdXenZ3Q0VBRT0iCn0K',
#         'messageId': '6730968907394344',
#         'message_id': '6730968907394344',
#         'publishTime': '2023-01-17T08:21:58.561Z',
#         'publish_time': '2023-01-17T08:21:58.561Z'
#     },
#     'subscription': 'projects/pipelines-sandbox/subscriptions/wordcount-push'
# }
@functions_framework.http
def execute_cloud_workflow(request):
    """HTTP Cloud Function.
    Args:
        request (flask.Request): The request object.
        <https://flask.palletsprojects.com/en/1.1.x/api/#incoming-request-data>
    Returns:
        The response text, or any set of values that can be turned into a
        Response object using `make_response`
        <https://flask.palletsprojects.com/en/1.1.x/api/#flask.make_response>.
    """

    from google.cloud import workflows_v1beta
    from google.cloud.workflows import executions_v1beta
    from google.cloud.workflows.executions_v1beta.types import executions
    from google.cloud.workflows.executions_v1beta.types import Execution
    import json
    import os
    import logging

    # These should be env variables
    project = os.environ.get('PROJECT')
    region = os.environ.get('REGION')
    workflow = os.environ.get('CLOUD_WORKFLOW_NAME')
    pyspark_file = os.environ.get('PYSPARK_FILE')
    spark_service_account = os.environ.get('SPARK_SERVICE_ACCOUNT')
    bq_output_table = os.environ.get('BQ_OUTPUT_TABLE')
    spark_temp_bucket = os.environ.get('SPARK_TEMP_BUCKET') # format bucket/path/ without gs://

    request_json = request.get_json(silent=True)

    print(f"request JSON: {request_json}")

    source_bucket = request_json['message']['attributes']['bucketId']
    source_object = request_json['message']['attributes']['objectId']
    source_file_path = f"gs://{source_bucket}/{source_object}"

    logging.info(f"file: ${source_file_path}")

    execution_client = executions_v1beta.ExecutionsClient()

    workflow_arguments_dict = {
        "pyspark_file": pyspark_file,
        "spark_job_args": [f"--input_expression={source_file_path}",
                           f"--output_table={bq_output_table}",
                           f"--temp_bucket={spark_temp_bucket}"
                           ],
        "spark_dep_jars": ["gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.13-0.27.1.jar"],
        "dataproc_runtime_version": "2.0",
        "project": f"{project}",
        "dataproc_region": f"{region}",
        "spark_service_account": f"{spark_service_account}",
        "spark_job_name_prefix": "wordcount-workflows-"
    }

    # Initialize request argument(s)
    request = executions_v1beta.CreateExecutionRequest(
        parent=f"projects/{project}/locations/{region}/workflows/{workflow}",
        execution=Execution(argument=json.dumps(workflow_arguments_dict))
    )

    # Execute the workflow.
    response = execution_client.create_execution(request)

    msg = f"Created execution: {response.name} for file {source_file_path}"
    logging.info(msg)
    print(msg)

    return msg


SELECT
jsonPayload.file AS gcs_file,
PARSE_TIMESTAMP("%F %k:%M:%E*S", REPLACE(REPLACE(jsonPayload.file_creation_time, 'T',' '),'Z','')) AS file_creation_time,
jsonPayload.tracker AS tracker,
jsonPayload.workflow_execution AS workflow_execution
FROM `${project}.${dataset}.${functions_log_table}`
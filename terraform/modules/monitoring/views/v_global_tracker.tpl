SELECT
f.gcs_file,
f.file_creation_time,
f.tracker,
f.workflow_execution,
w.workflow_start_time,
w.workflow_end_time,
w.workflow_status
FROM `${project}.${dataset}.${v_functions_tracker}` f
LEFT JOIN `${project}.${dataset}.${v_workflows_tracker}` w ON f.tracker = w.tracker
    SELECT
      CONCAT(resource.labels.workflow_id, "/", labels.workflows_googleapis_com_execution_id) AS workflow_execution_id,
      MAX(JSON_EXTRACT_SCALAR(jsonpayload_type_executionssystemlog.start.argument, '$.tracker')) AS tracker,
      MIN(jsonpayload_type_executionssystemlog.activitytime) AS workflow_start_time,
      MAX(jsonpayload_type_executionssystemlog.activitytime) AS workflow_end_time,
      MAX(jsonpayload_type_executionssystemlog.success.result) AS workflow_status
    FROM ${project}.${dataset}.${workflows_log_table}
    GROUP BY 1
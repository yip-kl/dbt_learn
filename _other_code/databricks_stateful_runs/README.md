# Introduction
Natively Databricks does not support stateful runs (see [here](https://github.com/databricks/dbt-databricks/blob/main/docs/databricks-workflows.md#retrieve-dbt-artifacts-using-the-jobs-api)), but we can work around this by storing the artifact and calling them by structuring the Workflow as below. IMPORTANT NOTE: directly using mount path for the state won't work, somehow it has to be loaded to the cluster first

1. Define environment variables for the dbt CLI cluster, for example:
```
DBT_ARTIFACT_MOUNT_PATH=/mnt/dbt_state
DBT_ARTIFACT_LOCAL_PATH=/tmp/dbt_state
DBT_ARTIFACT_STATE_PATH=/tmp/dbt_state/target
```
2. Download artifact to the cluster, refer to `_other_code/databricks_stateful_runs/download_artifact.ipynb`
3. Run dbt with `dbt run --select state:xxx`
4. Upload the artifact of the current run to ADLS, refer to `_other_code/databricks_stateful_runs/upload_artifact.ipynb`
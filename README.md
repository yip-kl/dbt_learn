# General knowledge
## Project initialization
1. Create venv
2. Activate the venv and install dbt-bigquery
3. Run dbt init {dbt project name} --profiles-dir {an existing folder to store the profiles.yml}. A folder will be created for your project
4. Move the profiles.yml to the folder created in #3
5. cd to the project, and dbt debug to make sure everything works fine
## Target dataset
- If schema is defined in the `model` section of `dbt_project.yml`, the schema defined in `profiles.yml` will be concatenated to those defined in `dbt_project.yml`. In our case the output dataset are called "dev_dbt_marts" and "dev_dbt_staging"
## Multi-location query
- It appears dbt can only take the location defined in `profiles.yml` as the query location. Setting under `dbt_project.yml` has no effect
- A potential workaround is to create another profile file, then refer to this profile file using the `--profiles-dir` option when run
## Re-run from point of failure
- Rerun models associated with failed tests with this command `dbt build --select 1+result:fail+ --defer --state ./target`. See more [here](https://docs.getdbt.com/reference/node-selection/methods#the-result-method)
- This should be added as part of the DAG, see more [here](https://docs.getdbt.com/blog/dbt-airflow-spiritual-alignment#rerunning-jobs-from-failure)

# Things to learn
- Productivity https://github.com/innoverio/vscode-dbt-power-user/issues/402
- Observability: breakdown each data model and log the result to BQ
- Github hooks e.g. https://github.com/dbt-labs/dbt-project-evaluator and others
- Trigger dbt core via Airflow K8s

# Best practice
- Data freshness and loaded time tracing
    - Add _etl_loaded_at timestamp to the tables, so that dbt can produce warning/error if necessary via `source freshness`
- Testing
    1. `dbt build --store-failures` which runs `dbt run` and `dbt test` iteratively for each model.
    2. Define the schema to store the failure results. Afterwards you can find the result of the failed tests in database
    3. Define severity (warn/error) of the tests
- Project structure
    - See [here](https://docs.getdbt.com/guides/best-practices/how-we-structure/1-guide-overview)
    - By default dbt materializes as Views, default materialization for different types of models can be defined in `dbt_project.yml`. Similarly `schema` can be defined to output the results to different locations. See [here](https://docs.getdbt.com/reference/model-configs)
- Re-run from point of failure
    - Rerun models associated with failed tests with this command `dbt build --select 1+result:fail+ --defer --state ./target`. See more [here](https://docs.getdbt.com/reference/node-selection/methods#the-result-method)
    - This should be added as part of the DAG, see more [here](https://docs.getdbt.com/blog/dbt-airflow-spiritual-alignment#rerunning-jobs-from-failure)

# dbt vs DLT
| Function               | dbt | DLT |
|------------------------|-----|-----|
| Scope       | - ETL: Transform only<br />- Output: The whole DW except for load, including Views, Tables, one-off queries| - ETL: Load and transform<br />- Output: Tables only|
| Language       | SQL + Jinja to allow loops and parameterization. Python is newly supported | Python and SQL  |
| Incremental handling       | Use `incremental` materialization, and define `unique_key` and cutoff time for new data | DLT tables are essentially materialized views |
| SCD support       | Yes via `snapshots` | Yes via `apply changes`  |
| Documentation      |- Lineage: Auto-generated <br />- Description: Provided in .yml file, can support parameterization<br />- Target: Source and Output<br />- Maintenance: Need to run `dbt docs generate`, and require server setup|- Lineage: Auto-generated<br />- Description: Provided in `COMMENT`, no parameterization<br />- Target: Source (if created in the DLT pipeline) and Output<br />- Maintenance: Auto-refresh and self-hosted|
| Development       |- Mode: Can run all/single SQL/anything upstream/downstream<br />- Environment and output destination: Managed using `profiles.yml` (for environment) and `dbt_project.yml` (for datasets) giving more flexibility | - Mode: Run all<br />- Environment: Defined in the pipeline setting, can only define one single schema, see [here](https://learn.microsoft.com/en-us/azure/databricks/delta-live-tables/updates#--development-and-production-modes)|
| Testing (incl. data freshness)|- Target: Source and Output<br />- Method: Warn or Fail|- Target: Source (if created in the DLT pipeline) and Output<br />- Method: Warn, Drop, Fail|
| Niche       |- Can include one-off SQL via `analyses` and small CSV load via `seed`<br />- Allows importing packages|- Auto-perform OPTIMIZE and VACUUM which is useful for Databricks|
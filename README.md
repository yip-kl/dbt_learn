# General knowledge
## Project initialization
1. Create venv
2. Activate the venv and install dbt-{adapter}. The adapter should support the corresponding dbt version, otherwise downgrade dbt-core
3. Run `dbt init {dbt project name} --profiles-dir {an existing folder to store the profiles.yml}`. A folder will be created for your project
4. Move the profiles.yml to the folder created in #3
5. cd to the project, and run `dbt debug` to make sure everything works fine
## Target dataset
- If schema is defined in the `model` section of `dbt_project.yml`, the schema defined in `profiles.yml` will be concatenated to those defined in `dbt_project.yml`. In our case the output dataset are called "dev_dbt_marts" and "dev_dbt_staging"
## Multi-location query
- It appears dbt can only take the location defined in `profiles.yml` as the query location. Setting under `dbt_project.yml` has no effect
- A potential workaround is to create another profile file, then refer to this profile file using the `--profiles-dir` option when run
## Authentication
**Azure Synapse**
1. Create App Registration, and make sure the service principal has `Storage Blob Data Contributor` access to the container concerned
2. Grant the service principal access to the SQL Pool
    ```
     create user [service_principal_name] from external PROVIDER
     exec sp_addrolemember 'db_owner', [service_principal_name]
    ```
3. In dbt project's `profiles.yml`, set up the `authentication` flag = ServicePrincipal with associated configurations, then test locally with `dbt debug`. Refer to [here](https://docs.getdbt.com/reference/warehouse-setups/mssql-setup#azure-active-directory-authentication-aad) for more details
4. dbt runs can be scheduled with Databricks, and like what we do locally we need to install Microsoft ODBC driver into the dbt CLI cluster:
    - Download the necessary files to somewhere like below
        ```
        %sh
        sudo curl -k https://packages.microsoft.com/keys/microsoft.asc > /dbfs/FileStore/odbc_install/microsoft.asc 
        sudo curl -k https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /dbfs/FileStore/odbc_install/prod.list
        ```
    - Create a start up script as such. This can be replaced to Workspace per Databricks' [recommendation](https://learn.microsoft.com/en-us/azure/databricks/clusters/init-scripts#configure-a-cluster-scoped-init-script-using-the-ui)
        ```
        #!/bin/bash
        sudo apt-key add /dbfs/FileStore/odbc_install/microsoft.asc
        sudo cp -f /dbfs/FileStore/odbc_install/prod.list /etc/apt/sources.list.d/mssql-release.list
        sudo apt-get update
        sudo ACCEPT_EULA=Y apt-get install msodbcsql18
        ```
    - Have the dbt CLI cluster in Job config to refer to this start up script

# Things to learn
- Secret management e.g. client secret in profiles.yml
- Github hooks e.g. https://github.com/dbt-labs/dbt-project-evaluator and others
- Trigger dbt core via Airflow K8s


# Best practice
- **Must install**
    - VS Code extensions
        - dbt Power User / Osmosis: dbt Cloud like development experience
    - dbt packages
        - [dbt-external-tables](https://github.com/dbt-labs/dbt-external-tables): With this one can create external tables in data warehouse e.g. external tables in Dedicated SQL Pool with source from ADLS. However, it appears full schema need to be defined even for self-described formats like Parquet
        - [elementary](https://www.elementary-data.com/): Add observability e.g. model run duration by parsing artifacts, does not seem to support Synapse though. Neither does `dbt Artifacts`
        - [dbt_utils](https://hub.getdbt.com/dbt-labs/dbt_utils/latest/): General macros library
        - [tsql_utils](https://hub.getdbt.com/dbt-msft/tsql_utils/latest/): Necessary for Synapse
- **Data freshness and loaded time tracing**
    - Add _etl_loaded_at timestamp to the tables, so that dbt can produce warning/error if necessary via `source freshness`
- **Testing**
    1. `dbt build --store-failures` which runs `dbt run` and `dbt test` iteratively for each model, and stores failure to designated schema/dataset via [this](https://docs.getdbt.com/reference/resource-configs/schema#tests)
    2. Define the schema to store the failure results. Afterwards you can find the result of the failed tests in database
    3. Define severity (warn/error) of the tests
- **Project structure**
    - See [here](https://docs.getdbt.com/guides/best-practices/how-we-structure/1-guide-overview)
    - By default dbt materializes as Views, default materialization for different types of models can be defined in `dbt_project.yml`. Similarly `schema` can be defined to output the results to different locations. See [here](https://docs.getdbt.com/reference/model-configs)
- **State backend on cloud**
dbt stores state after runs, but natively it does not provide a way to persist it on cloud storage like what Terraform does. However, this is critical for the following reasons. An example of how to work around it in Databricks is stated under `_other_code/databricks_stateful_runs/`
    - Allow stateful runs and Slim CI to run failed models, or models that have been modified e.g.
    ```
    `dbt build --select 1+result:fail+ --defer --state ./target`
    ```
    - Providing data for observability

    

# dbt vs DLT
| Function               | dbt | DLT |
|------------------------|-----|-----|
| Scope       | - ETL: Transform only<br />- Output: The whole DW except for load, including Views, Tables, one-off queries| - ETL: Load and transform<br />- Output: Tables only|
| Language       | SQL + Jinja to allow loops and parameterization, Python is newly supported | Python and SQL, but they cannot be run under the same notebook  |
| Target       | All supported data warehouses | Databricks / Serverless variants e.g. Synpase Serverless SQL pool only  |
| Incremental handling       | Use `incremental` materialization, and define `unique_key` and cutoff time for new data. Can also support full refresh via `dbt run --full-refresh` | DLT tables are essentially materialized views |
| SCD support       | Yes via `snapshots` | Yes via `apply changes`  |
| Documentation      |- Lineage: Auto-generated <br />- Description: Provided in .yml file, can support parameterization<br />- Target: Source and Output<br />- Maintenance: Need to run `dbt docs generate`, and require server setup|- Lineage: Auto-generated<br />- Description: Provided in `COMMENT`, no parameterization<br />- Target: Source (if created in the DLT pipeline) and Output<br />- Maintenance: Auto-refresh and self-hosted|
| Development       |- Mode: Can run all/single SQL/anything upstream/downstream<br />- Environment and output destination: Managed using `profiles.yml` (for environment) and `dbt_project.yml` (for datasets) giving more flexibility | - Mode: Run all<br />- Environment: Defined in the pipeline setting, can only define one single schema, see [here](https://learn.microsoft.com/en-us/azure/databricks/delta-live-tables/updates#--development-and-production-modes)|
| Testing (incl. data freshness)|- Target: Source and Output<br />- Method: Warn or Fail|- Target: Source (if created in the DLT pipeline) and Output<br />- Method: Warn, Drop, Fail|
| Niche       |- Can include one-off SQL via `analyses` and small CSV load via `seed`<br />- Allows importing packages|- Auto-perform OPTIMIZE and VACUUM which is useful for Databricks|

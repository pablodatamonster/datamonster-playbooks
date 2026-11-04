/* =====================================================================
   Snowflake account setup for a client project (DataMonster playbook)
   Placeholders: CLIENT_PILOT (database), ITADMIN (admin user),
   RM_CLIENT_PILOT_MONTHLY (spending cap). Replace before running.
   Run in a Snowsight worksheet as ITADMIN, one block at a time.
   Safe to re-run: every statement uses IF NOT EXISTS or OR REPLACE
   only where nothing can be lost.
   ===================================================================== */


/* ---------------------------------------------------------------------
   BLOCK 1 · Account basics and the spending cap
   Who: ACCOUNTADMIN, the only role allowed to set account-wide limits.
   --------------------------------------------------------------------- */
USE ROLE ACCOUNTADMIN;

-- Show every timestamp in local time (default is US Pacific). Change if needed.
ALTER ACCOUNT SET TIMEZONE = 'Europe/London';

-- A resource monitor is Snowflake's spending cap, counted in credits.
-- 25 credits a month is a modest budget for a pilot; check the price per
-- credit for your edition and region. An X-Small warehouse uses 1 credit
-- per hour, billed per second, only while it is running.
CREATE RESOURCE MONITOR IF NOT EXISTS RM_CLIENT_PILOT_MONTHLY
  WITH CREDIT_QUOTA = 25
       FREQUENCY = MONTHLY
       START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
       ON 50  PERCENT DO NOTIFY             -- email at half way
       ON 80  PERCENT DO NOTIFY             -- email at 80%
       ON 100 PERCENT DO SUSPEND            -- stop new queries, let running ones finish
       ON 110 PERCENT DO SUSPEND_IMMEDIATE; -- hard stop

-- Apply the cap to the whole account, so every warehouse counts towards it.
ALTER ACCOUNT SET RESOURCE_MONITOR = RM_CLIENT_PILOT_MONTHLY;


/* ---------------------------------------------------------------------
   BLOCK 2 · Roles (who can do what)
   Who: SECURITYADMIN, the role that manages users, roles and grants.
   One role per job, so each tool gets only the access it needs.
   --------------------------------------------------------------------- */
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS LOADER
  COMMENT = 'Writes incoming files into RAW (upload page or loader)';
CREATE ROLE IF NOT EXISTS TRANSFORMER
  COMMENT = 'Runs dbt: reads RAW, builds STAGING and MARTS';
CREATE ROLE IF NOT EXISTS REPORTER
  COMMENT = 'Reads MARTS only (BI tool and MCP)';

-- Hang the new roles under SYSADMIN, as Snowflake recommends,
-- so admins can always see and manage what they create.
GRANT ROLE LOADER      TO ROLE SYSADMIN;
GRANT ROLE TRANSFORMER TO ROLE SYSADMIN;
GRANT ROLE REPORTER    TO ROLE SYSADMIN;

-- Let the admin user switch into each role for testing.
GRANT ROLE LOADER      TO USER ITADMIN;
GRANT ROLE TRANSFORMER TO USER ITADMIN;
GRANT ROLE REPORTER    TO USER ITADMIN;


/* ---------------------------------------------------------------------
   BLOCK 3 · Warehouses (the compute engines)
   Who: SYSADMIN, the role that owns databases and warehouses.
   Two small warehouses so the cost of building the data and the cost
   of serving dashboards can be measured separately for the demo.
   --------------------------------------------------------------------- */
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS WH_TRANSFORM
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60               -- pause after 60 seconds idle
  AUTO_RESUME = TRUE              -- wake up when a query arrives
  INITIALLY_SUSPENDED = TRUE      -- do not start (or bill) now
  STATEMENT_TIMEOUT_IN_SECONDS = 1800
  COMMENT = 'Loading and dbt runs';

CREATE WAREHOUSE IF NOT EXISTS WH_REPORTING
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  STATEMENT_TIMEOUT_IN_SECONDS = 600
  COMMENT = 'BI extracts and MCP questions';

GRANT USAGE ON WAREHOUSE WH_TRANSFORM TO ROLE LOADER;
GRANT USAGE ON WAREHOUSE WH_TRANSFORM TO ROLE TRANSFORMER;
GRANT USAGE ON WAREHOUSE WH_REPORTING TO ROLE REPORTER;


/* ---------------------------------------------------------------------
   BLOCK 4 · Database and layers
   RAW      files exactly as received
   STAGING  cleaned and typed (built by dbt)
   MARTS    final metrics for dashboards and the MCP (built by dbt)
   --------------------------------------------------------------------- */
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS CLIENT_PILOT
  DATA_RETENTION_TIME_IN_DAYS = 7   -- Time Travel: undo window of 7 days
  COMMENT = 'Client pilot';

CREATE SCHEMA IF NOT EXISTS CLIENT_PILOT.RAW     COMMENT = 'Files as received';
CREATE SCHEMA IF NOT EXISTS CLIENT_PILOT.STAGING COMMENT = 'Cleaned and typed, built by dbt';
CREATE SCHEMA IF NOT EXISTS CLIENT_PILOT.MARTS   COMMENT = 'Final metrics, built by dbt';

-- dbt must own the schemas it builds into.
GRANT OWNERSHIP ON SCHEMA CLIENT_PILOT.STAGING TO ROLE TRANSFORMER COPY CURRENT GRANTS;
GRANT OWNERSHIP ON SCHEMA CLIENT_PILOT.MARTS   TO ROLE TRANSFORMER COPY CURRENT GRANTS;


/* ---------------------------------------------------------------------
   BLOCK 5 · Access to the layers
   Who: SECURITYADMIN (it can grant on objects other roles own).
   "FUTURE" grants cover tables that do not exist yet, so nothing
   needs re-granting each time dbt rebuilds a model.
   --------------------------------------------------------------------- */
USE ROLE SECURITYADMIN;

GRANT USAGE ON DATABASE CLIENT_PILOT TO ROLE LOADER;
GRANT USAGE ON DATABASE CLIENT_PILOT TO ROLE TRANSFORMER;
GRANT USAGE ON DATABASE CLIENT_PILOT TO ROLE REPORTER;

-- LOADER: write into RAW only.
GRANT USAGE, CREATE TABLE, CREATE STAGE, CREATE FILE FORMAT
  ON SCHEMA CLIENT_PILOT.RAW TO ROLE LOADER;

-- TRANSFORMER: read everything in RAW; may create its own dev schemas.
GRANT USAGE ON SCHEMA CLIENT_PILOT.RAW TO ROLE TRANSFORMER;
GRANT SELECT ON ALL TABLES    IN SCHEMA CLIENT_PILOT.RAW TO ROLE TRANSFORMER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CLIENT_PILOT.RAW TO ROLE TRANSFORMER;
GRANT CREATE SCHEMA ON DATABASE CLIENT_PILOT TO ROLE TRANSFORMER;

-- REPORTER: read MARTS only. Never RAW or STAGING.
GRANT USAGE ON SCHEMA CLIENT_PILOT.MARTS TO ROLE REPORTER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA CLIENT_PILOT.MARTS TO ROLE REPORTER;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA CLIENT_PILOT.MARTS TO ROLE REPORTER;


/* ---------------------------------------------------------------------
   BLOCK 6 · Check it all worked
   --------------------------------------------------------------------- */
USE ROLE ACCOUNTADMIN;
SHOW RESOURCE MONITORS;
SHOW WAREHOUSES;
SHOW SCHEMAS IN DATABASE CLIENT_PILOT;
SHOW GRANTS TO ROLE REPORTER;

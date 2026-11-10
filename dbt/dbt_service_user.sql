/* =====================================================================
   dbt service user for a client project (DataMonster playbook)
   Placeholders: CLIENT_PILOT (database), SVC_DBT (service user),
   <public key body> (from the .pub file, one line). Replace before running.
   Needs: role TRANSFORMER and warehouse WH_TRANSFORM from the Snowflake
   account setup playbook.
   Run in a Snowsight worksheet as the admin user, one block at a time.
   ===================================================================== */


/* ---------------------------------------------------------------------
   BLOCK 1 · The service user (key-pair sign-in)
   Run with: USERADMIN · no warehouse
   Expect: "User SVC_DBT successfully created.", then DESC USER shows
   TYPE = SERVICE, DEFAULT_ROLE = TRANSFORMER and RSA_PUBLIC_KEY_FP
   matching the fingerprint worked out on the laptop.
   --------------------------------------------------------------------- */
USE ROLE USERADMIN;
CREATE USER IF NOT EXISTS SVC_DBT
  TYPE = SERVICE                       -- no password, no Snowsight sign-in
  DEFAULT_ROLE = TRANSFORMER
  DEFAULT_WAREHOUSE = WH_TRANSFORM
  DEFAULT_NAMESPACE = CLIENT_PILOT.STAGING
  RSA_PUBLIC_KEY = '<public key body>'
  COMMENT = 'dbt. Key pair only; private key in the password manager. Role TRANSFORMER';
GRANT ROLE TRANSFORMER TO USER SVC_DBT;
ALTER USER SVC_DBT SET STATEMENT_TIMEOUT_IN_SECONDS = 600;  -- cost guard
ALTER USER SVC_DBT SET DEFAULT_SECONDARY_ROLES = ();        -- TRANSFORMER only
DESC USER SVC_DBT;


/* ---------------------------------------------------------------------
   BLOCK 2 · Check TRANSFORMER sees what dbt needs
   Run with: TRANSFORMER · WH_TRANSFORM · one statement at a time
   Write down the expected row count before running 2a.
   --------------------------------------------------------------------- */
USE ROLE TRANSFORMER;
USE SECONDARY ROLES NONE;            -- see exactly what the role can do
USE WAREHOUSE WH_TRANSFORM;
SELECT COUNT(*) FROM CLIENT_PILOT.RAW.<raw_table>;     -- 2a
SHOW SCHEMAS IN DATABASE CLIENT_PILOT;                 -- 2b: RAW, STAGING, MARTS
USE SECONDARY ROLES ALL;             -- back to normal for your own login


/* ---------------------------------------------------------------------
   Rotating the key later
   1. Make a new pair. 2. ALTER USER SVC_DBT SET RSA_PUBLIC_KEY_2 = '...';
   3. Point profiles.yml at the new key and run dbt debug.
   4. ALTER USER SVC_DBT UNSET RSA_PUBLIC_KEY;
   --------------------------------------------------------------------- */

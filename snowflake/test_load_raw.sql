/* =====================================================================
   First test load into RAW (DataMonster playbook, step 8)
   Loads one month of CSV files into CLIENT_PILOT.RAW to prove the
   file format loads. Run in a Snowsight worksheet, one block at a time.

   Example file (made up): one CSV per store per month, columns
     sale_month, sale_id, store_code, product_code, amount, refund_date
   where refund_date is optional (some stores do not send the column).
   Replace the columns with your own file format.

   Run with: role LOADER · warehouse WH_TRANSFORM · CLIENT_PILOT.RAW
   (Block 6 switches to TRANSFORMER for one check.)
   In block 6, run one statement at a time (Ctrl+Enter): Snowsight
   shows only the last result when several run together.
   ===================================================================== */


/* ---------------------------------------------------------------------
   BLOCK 1 · Set the context
   A worksheet always runs as one role, on one warehouse, in one
   database and schema. Setting them here lets every statement below
   use short names.
   --------------------------------------------------------------------- */
USE ROLE LOADER;            -- may write into RAW only
USE WAREHOUSE WH_TRANSFORM; -- compute for loading; wakes up when needed
USE DATABASE CLIENT_PILOT;
USE SCHEMA RAW;


/* ---------------------------------------------------------------------
   BLOCK 2 · A file format: how to read the CSV files
   - PARSE_HEADER: read column names from the first row, so columns are
     matched by name, not position (copes with a missing optional column).
   - FIELD_OPTIONALLY_ENCLOSED_BY: values may be wrapped in quotes.
   - EMPTY_FIELD_AS_NULL: a blank value is stored as NULL.
   Metadata only: uses no warehouse compute.
   --------------------------------------------------------------------- */
CREATE FILE FORMAT IF NOT EXISTS FF_CSV
  TYPE = CSV
  PARSE_HEADER = TRUE
  FIELD_DELIMITER = ','
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  EMPTY_FIELD_AS_NULL = TRUE
  ENCODING = 'UTF8'
  COMMENT = 'Incoming CSV files (test load)';


/* ---------------------------------------------------------------------
   BLOCK 3 · A stage: the landing area for files
   A private folder inside Snowflake, encrypted (SNOWFLAKE_SSE).
   DIRECTORY = ENABLE lets Snowsight list the files in it.
   Metadata only: uses no warehouse compute.
   --------------------------------------------------------------------- */
CREATE STAGE IF NOT EXISTS STG_FILES
  FILE_FORMAT = FF_CSV
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Landing area for incoming files';


/* ---------------------------------------------------------------------
   BLOCK 4 · The RAW table
   RAW keeps files exactly as received, so every column is text.
   Nothing is rejected for a type here; dbt types the data in STAGING.
   SOURCE_FILE, SOURCE_ROW and LOADED_AT trace each row to its file.
   Metadata only: uses no warehouse compute.
   --------------------------------------------------------------------- */
CREATE TABLE IF NOT EXISTS RAW_ROWS (
  SALE_MONTH    VARCHAR,
  SALE_ID       VARCHAR,
  STORE_CODE    VARCHAR,
  PRODUCT_CODE  VARCHAR,
  AMOUNT        VARCHAR,
  REFUND_DATE   VARCHAR,
  SOURCE_FILE   VARCHAR,
  SOURCE_ROW    NUMBER,
  LOADED_AT     TIMESTAMP_LTZ
)
COMMENT = 'Incoming file rows as received (all text)';


/* ---------------------------------------------------------------------
   STEP 5a · Upload the files (in Snowsight, not SQL)
   Switch to role LOADER (bottom left), then Ingestion > Add data >
   Load files into a Stage. Pick schema CLIENT_PILOT.RAW and stage
   STG_FILES, Browse, choose the month's files and type the path
   2026-10 so they land in a folder of that name.
   Then check they arrived (metadata only):
   --------------------------------------------------------------------- */
LIST @STG_FILES/2026-10/;


/* ---------------------------------------------------------------------
   BLOCK 5 · Copy the files into the table
   - MATCH_BY_COLUMN_NAME: file columns go to table columns of the same
     name (any case); a column the file lacks is left NULL.
   - INCLUDE_METADATA: fill the three "where from" columns.
   - ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE: required with
     INCLUDE_METADATA on CSV (the table is wider than the files). Rows
     with a wrong number of fields are therefore not stopped here:
     check them before files reach the stage.
   - ON_ERROR = ABORT_STATEMENT: all or nothing.
   Snowflake remembers loaded files for 64 days, so a rerun skips them.
   Uses WH_TRANSFORM for a few seconds.
   --------------------------------------------------------------------- */
COPY INTO RAW_ROWS
  FROM @STG_FILES/2026-10/
  FILE_FORMAT = (FORMAT_NAME = 'FF_CSV'
                 ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE)
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
  INCLUDE_METADATA = (
    SOURCE_FILE = METADATA$FILENAME,
    SOURCE_ROW  = METADATA$FILE_ROW_NUMBER,
    LOADED_AT   = METADATA$START_SCAN_TIME
  )
  ON_ERROR = ABORT_STATEMENT;


/* ---------------------------------------------------------------------
   BLOCK 6 · Check the load
   Work out the expected numbers from the same files before loading
   (for example with a short Python script), then compare.
   --------------------------------------------------------------------- */

-- 6a. Rows per file
SELECT SOURCE_FILE, COUNT(*) AS ROWS_LOADED
FROM RAW_ROWS
GROUP BY SOURCE_FILE
ORDER BY ROWS_LOADED DESC;

-- 6b. Totals: rows, unique IDs, months, blanks, values that should be numbers
SELECT COUNT(*)                   AS ROWS_LOADED,
       COUNT(DISTINCT SALE_ID)    AS UNIQUE_IDS,
       COUNT(DISTINCT SALE_MONTH) AS MONTHS,
       COUNT(REFUND_DATE)         AS REFUND_DATES,
       COUNT_IF(TRY_TO_NUMBER(AMOUNT, 12, 2) IS NULL) AS AMOUNT_NOT_A_NUMBER
FROM RAW_ROWS;

-- 6c. A file without the optional column (replace the file name)
SELECT COUNT(*) AS ROWS_LOADED, COUNT(REFUND_DATE) AS REFUND_DATES
FROM RAW_ROWS
WHERE SOURCE_FILE ILIKE '%STORE_007%';

-- 6d. A first look at ten rows
SELECT * FROM RAW_ROWS LIMIT 10;

-- 6e. Snowflake's own record of the load (one line per file)
SELECT FILE_NAME, STATUS, ROW_COUNT, ROW_PARSED, FIRST_ERROR_MESSAGE, LAST_LOAD_TIME
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
       TABLE_NAME => 'CLIENT_PILOT.RAW.RAW_ROWS',
       START_TIME => DATEADD(HOUR, -2, CURRENT_TIMESTAMP())))
ORDER BY FILE_NAME;

-- 6f. Run BLOCK 5 again: expect "Copy executed with 0 files processed",
--     then rerun 6b: the totals must not change.

-- 6g. dbt reads RAW as TRANSFORMER: check it can (future grant).
USE ROLE TRANSFORMER;
SELECT COUNT(*) FROM CLIENT_PILOT.RAW.RAW_ROWS;
USE ROLE LOADER;


/* ---------------------------------------------------------------------
   UNDO (only if needed)
     TRUNCATE TABLE RAW_ROWS;
     -- then add FORCE = TRUE to the COPY in block 5 for one run
   --------------------------------------------------------------------- */

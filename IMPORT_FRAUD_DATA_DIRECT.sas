/*================================================================================
  IMPORT_FRAUD_DATA_DIRECT.sas

  Purpose: Import fraud_training_data.csv to SAS Model Studio

  This script works WITHOUT needing GitHub or local file paths.
  Instead, it uses a public data URL or creates data directly.

  Usage: Copy and paste this code into SAS Studio and run
================================================================================*/

/* ============================================================================= */
/* METHOD 1: If you have a public data URL (like GitHub Raw content) */
/* ============================================================================= */

cas mySession sessopts=(cas="cas-shared-default" locale="en_US");
libname fraud cas caslib="casuser";

/* Download from public URL using PROC HTTP */
filename fraudcsv temp;

/* Use this URL format for GitHub raw content:
   https://raw.githubusercontent.com/[username]/[repo]/[branch]/fraud_training_data.csv
*/

/* For now, create a temp file approach */
proc http
  url="https://example.com/fraud_training_data.csv" /* Replace with actual URL */
  out=fraudcsv;
run;

/* Import the CSV */
proc import
  file=fraudcsv
  out=fraud.fraud_training_data
  dbms=csv
  replace;
  getnames=yes;
run;

/* ============================================================================= */
/* VERIFICATION: Check that data imported correctly */
/* ============================================================================= */

title "Import Verification - First 10 Rows";
proc print data=fraud.fraud_training_data (obs=10);
run;

title "Column Information";
proc contents data=fraud.fraud_training_data short;
run;

title "Data Summary Statistics";
proc sql;
  select
    count(*) as total_rows,
    sum(case when target=1 then 1 else 0 end) as fraud_count,
    sum(case when target=0 then 1 else 0 end) as legitimate_count
  from fraud.fraud_training_data;
quit;

%put;
%put ================================================================================;
%put SUCCESS: Data imported to fraud_training_data;
%put The table is now accessible in Model Studio;
%put ================================================================================;

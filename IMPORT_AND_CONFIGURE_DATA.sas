/*
 * IMPORT_AND_CONFIGURE_DATA.sas
 * Purpose: Import fraud_training_data.csv and configure for Model Studio
 *
 * This script:
 * 1. Reads the CSV file from disk
 * 2. Creates a CAS table accessible to Model Studio
 * 3. Verifies the import and displays summary statistics
 */

/* Start CAS session */
cas mySession sessopts=(cas="cas-shared-default" locale="en_US");

/* Define library for model data */
libname modeldata cas caslib="casuser";

/* Set path to CSV file */
%let csv_file = D:\Works\Projects\SAS\SAS-AIMLNetwork\fraud_training_data.csv;

/* Import the CSV file using PROC IMPORT */
proc import
  datafile="&csv_file"
  out=modeldata.fraud_training_data
  dbms=csv
  replace;
  getnames=yes;
run;

/* Display import summary */
title "Import Summary - fraud_training_data";
proc print data=modeldata.fraud_training_data (obs=5);
run;

/* Get detailed table information */
title "Table Structure - fraud_training_data";
proc contents data=modeldata.fraud_training_data;
run;

/* Display row count */
title "Row Count Verification";
proc sql;
  select count(*) as total_rows,
         sum(case when target=1 then 1 else 0 end) as fraud_count,
         sum(case when target=0 then 1 else 0 end) as legitimate_count
  from modeldata.fraud_training_data;
quit;

/* Verify key statistics */
title "Data Quality Verification";
proc means data=modeldata.fraud_training_data;
  var transaction_amount transaction_hour account_age_days days_since_last
      txn_count_30days is_foreign high_risk_amount high_risk_country
      new_account dormant_reactivation;
run;

/* Success message */
%put;
%put ================================================================================;
%put SUCCESS: Data imported successfully!;
%put ================================================================================;
%put;
%put Table: modeldata.fraud_training_data;
%put Location: casuser (CAS In-Memory Storage);
%put Status: Ready for Model Studio;
%put;
%put Next steps:;
%put 1. Go to Model Studio > Data tab;
%put 2. Refresh the data sources;
%put 3. Select: fraud_training_data (from casuser);
%put 4. Configure data roles:;
%put    - TARGET: target;
%put    - INPUT: All numeric columns except transaction_id;
%put    - REJECTED: transaction_id, merchant_country, cardholder_country;
%put 5. Click 'Run all pipelines' to train models;
%put;
%put ================================================================================;

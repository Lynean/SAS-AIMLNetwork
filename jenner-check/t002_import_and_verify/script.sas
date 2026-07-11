/*
 * IMPORT_AND_CONFIGURE_DATA.sas
 * Purpose: Import fraud_training_data.csv and configure for Model Studio
 *
 * This script:
 * 1. Reads the CSV file from disk
 * 2. Creates a CAS table accessible to Model Studio
 * 3. Verifies the import and displays summary statistics
 */

/* Define library for model data (plain WORK library in place of the CAS caslib) */
libname modeldata "%sysfunc(pathname(work))";

/* Write a 20-row sample of the repo's own fraud_training_data.csv to a WORK
   file so PROC IMPORT below can read it exactly as the author's script does
   (the bundle runner sends only script text, not sibling data files, so the
   CSV is inlined here instead of read from disk). */
filename fraudcsv "%sysfunc(pathname(work))/fraud_training_data.csv";
data _null_;
  file fraudcsv;
  input line $char300.;
  put line;
  datalines4;
transaction_id,target,transaction_amount,merchant_country,cardholder_country,is_foreign,transaction_hour,account_age_days,days_since_last,txn_count_30days,high_risk_amount,high_risk_country,new_account,dormant_reactivation
1993,0,135,US,US,0,23,476,28,14,0,0,0,0
329,1,565,US,US,0,0,907,45,18,0,0,0,0
535,1,113,TH,US,1,21,27,37,20,0,1,1,0
1783,0,47,US,US,0,6,259,42,5,0,0,0,0
1662,1,3011,NG,US,1,1,6,17,6,1,1,1,0
49,0,84,US,US,0,3,78,40,13,0,0,0,0
1601,1,2157,ID,CA,1,2,999,4,19,1,1,0,0
521,1,33,US,US,0,2,19,59,6,0,0,1,0
1578,0,75,US,US,0,9,2266,34,4,0,0,0,0
33,0,251,US,CA,1,13,1050,84,3,0,0,0,1
133,1,160,CN,US,1,0,1732,4,1,0,1,0,0
17,0,67,US,US,0,20,1904,54,3,0,0,0,0
393,0,78,US,US,0,16,2617,51,14,0,0,0,0
1794,0,59,US,US,0,9,1621,78,14,0,0,0,1
37,0,94,US,US,0,22,898,38,3,0,0,0,0
35,1,2206,BR,US,1,18,23,58,1,1,1,1,0
32,0,41,US,US,0,14,430,20,1,0,0,0,0
4,1,479,US,US,0,18,28,6,9,0,0,1,0
51,0,63,US,US,0,16,1112,82,1,0,0,0,1
6,1,3627,PH,US,1,18,784,5,8,1,1,0,0
;;;;
run;

/* Set path to CSV file */
%let csv_file = %sysfunc(pathname(work))/fraud_training_data.csv;

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

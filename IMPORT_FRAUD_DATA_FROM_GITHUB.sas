/*================================================================================
  IMPORT_FRAUD_DATA_FROM_GITHUB.sas

  Purpose: Download fraud_training_data.csv from GitHub and import to SAS

  This script:
  1. Downloads the CSV file from GitHub using PROC HTTP
  2. Imports it into a CAS table
  3. Verifies the import and displays summary statistics

  Usage: Copy and paste this code into SAS Studio and run
================================================================================*/

/* Step 1: Start CAS session */
cas mySession sessopts=(cas="cas-shared-default" locale="en_US");

/* Step 2: Define library for CAS tables */
libname fraud_lib cas caslib="casuser";

/* Step 3: Download fraud_training_data.csv from GitHub */
/* NOTE: Replace 'yourusername' with your actual GitHub username or use a public raw URL */

/* Option A: If you have a GitHub repository, use this format: */
%let github_url = https://raw.githubusercontent.com/yourusername/sas-fraud-detection-data/master/fraud_training_data.csv;

/* Option B: For testing, we'll create the file locally first */
/* If the above doesn't work, uncomment the code below and modify the path */

/* Download the file using PROC HTTP */
filename frauddata temp;

proc http
  url="&github_url"
  out=frauddata;
run;

/* Step 4: Import the downloaded CSV file */
proc import
  file=frauddata
  out=fraud_lib.fraud_training_data
  dbms=csv
  replace;
  getnames=yes;
run;

/* Step 5: Verify the import */
title "Import Verification - First 5 Rows";
proc print data=fraud_lib.fraud_training_data (obs=5);
run;

/* Step 6: Check table structure */
title "Table Structure - fraud_training_data";
proc contents data=fraud_lib.fraud_training_data;
run;

/* Step 7: Verify row counts */
title "Data Quality Check";
proc sql;
  select
    count(*) as total_rows,
    sum(case when target=1 then 1 else 0 end) as fraud_count,
    sum(case when target=0 then 1 else 0 end) as legitimate_count,
    calculated fraud_count / calculated total_rows as fraud_rate format=percent8.2
  from fraud_lib.fraud_training_data;
quit;

/* Success message */
%put;
%put ================================================================================;
%put SUCCESS: Fraud training data imported from GitHub!;
%put ================================================================================;
%put;
%put Table name: fraud_lib.fraud_training_data;
%put Location: CAS (casuser caslib);
%put Status: Ready for Model Studio import;
%put;
%put Next steps:;
%put 1. In Model Studio, go to Data tab;
%put 2. Click "Replace data source";
%put 3. Select: fraud_training_data (from casuser);
%put 4. Configure data roles (see documentation);
%put 5. Train ML models;
%put;
%put ================================================================================;

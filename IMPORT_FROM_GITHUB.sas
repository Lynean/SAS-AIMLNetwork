/*================================================================================
  IMPORT_FROM_GITHUB.sas

  Purpose: Download fraud_training_data.csv from GitHub and import to SAS Model Studio

  This script downloads the CSV file from GitHub and imports it into a CAS table
  that Model Studio can use for ML model training.

  GitHub Repository: https://github.com/Lynean/SAS-AIMLNetwork
  Data File: fraud_training_data.csv (2,000 synthetic fraud transactions)
================================================================================*/

/* ========================================================================= */
/* STEP 1: Initialize CAS Session */
/* ========================================================================= */

cas mysession sessopts=(cas="cas-shared-default" locale="en_US");

/* ========================================================================= */
/* STEP 2: Define Library for CAS Tables */
/* ========================================================================= */

libname fraud_ml cas caslib="casuser";

/* ========================================================================= */
/* STEP 3: Download CSV from GitHub */
/* ========================================================================= */

/* Use FILENAME with URL to download directly from GitHub raw content */
filename frauddata url "https://raw.githubusercontent.com/Lynean/SAS-AIMLNetwork/main/fraud_training_data.csv";

/* ========================================================================= */
/* STEP 4: Import CSV into CAS Table */
/* ========================================================================= */

proc import
  file=frauddata
  out=fraud_ml.fraud_training_data
  dbms=csv
  replace;
  getnames=yes;
run;

/* ========================================================================= */
/* STEP 5: Verification - Display Summary Statistics */
/* ========================================================================= */

title "=== FRAUD TRAINING DATA IMPORT VERIFICATION ===";
title2 "Sample Data (First 10 Rows)";
proc print data=fraud_ml.fraud_training_data (obs=10);
run;

title "Table Structure";
proc contents data=fraud_ml.fraud_training_data short;
run;

title "Data Quality Summary";
proc sql;
  select
    count(*) as total_rows label="Total Rows",
    sum(case when target=1 then 1 else 0 end) as fraud_count label="Fraud Cases",
    sum(case when target=0 then 1 else 0 end) as legitimate_count label="Legitimate Cases",
    round(100 * sum(case when target=1 then 1 else 0 end) / count(*), 2) as fraud_rate label="Fraud Rate (%)",
    round(mean(transaction_amount), 2) as avg_transaction label="Avg Transaction ($)",
    min(transaction_amount) as min_amount label="Min Amount ($)",
    max(transaction_amount) as max_amount label="Max Amount ($)"
  from fraud_ml.fraud_training_data;
quit;

title "Column Summary";
proc means data=fraud_ml.fraud_training_data n mean std min max;
  var transaction_amount transaction_hour account_age_days days_since_last
      txn_count_30days is_foreign high_risk_amount high_risk_country
      new_account dormant_reactivation;
run;

/* ========================================================================= */
/* SUCCESS CONFIRMATION */
/* ========================================================================= */

%put;
%put ================================================================================;
%put;
%put   ✓ SUCCESS: Fraud training data imported from GitHub!;
%put;
%put   Table Name: fraud_ml.fraud_training_data;
%put   Library:    fraud_ml;
%put   CASlib:     casuser;
%put   Rows:       2,000 transactions;
%put   Columns:    14 (fraud indicator + 13 features);
%put;
%put ================================================================================;
%put;
%put NEXT STEPS - Configure Data in Model Studio:;
%put;
%put   1. Open Model Studio: https://poc.sas.env/SASModelStudio/;
%put   2. Go to: Fraud Detection ML Model > Data tab;
%put   3. Click: Refresh data sources;
%put   4. Select: fraud_training_data (from casuser);
%put   5. Configure data roles:;
%put      • TARGET: target;
%put      • INPUT: transaction_amount, transaction_hour, account_age_days,;
%put                days_since_last, txn_count_30days, is_foreign,;
%put                high_risk_amount, high_risk_country, new_account,;
%put                dormant_reactivation;
%put      • REJECTED: transaction_id, merchant_country, cardholder_country;
%put   6. Click: Pipelines tab;
%put   7. Click: Run all pipelines;
%put   8. Wait for model training to complete (2-5 minutes);
%put;
%put ================================================================================;
%put;

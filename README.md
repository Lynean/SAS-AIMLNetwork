# SAS Fraud Detection ML Model - Training Data

This repository contains the synthetic fraud training data for the SAS Fraud Detection ML Model project.

## Files

- **fraud_training_data.csv** - 2,000 synthetic fraud transaction records for ML model training
  - 2,000 rows
  - 14 columns including fraud indicator (target)
  - Ready for import into SAS Model Studio

## Download Data for SAS Import

Use this SAS code to download and import the data directly from GitHub:

```sas
/* Download fraud training data from GitHub */
filename fraudcsv url "https://raw.githubusercontent.com/yourusername/sas-fraud-detection-data/master/fraud_training_data.csv";

/* Import the CSV file */
proc import
  file=fraudcsv
  out=work.fraud_training_data
  dbms=csv
  replace;
  getnames=yes;
run;

/* Verify import */
proc print data=work.fraud_training_data (obs=5);
run;
```

## Project Status

- Data generation: ✅ Complete
- Data upload to GitHub: ⏳ In progress
- Model training: ⏳ Pending

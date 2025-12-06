/*
 * Import fraud_training_data.csv to SAS
 * Creates a CAS table that can be used in Model Studio
 */

/* First, define the CASLIB for the project */
cas mySession sessopts=(cas="cas-shared-default" locale="en_US");

/* Set the location where the CSV file is stored */
%let csv_path = D:\Works\Projects\SAS\SAS-AIMLNetwork\fraud_training_data.csv;

/* Create a CAS library for model data */
libname modelcas cas caslib="casuser" ;

/* PROC IMPORT to read the CSV file */
proc import 
  datafile="&csv_path"
  out=modelcas.fraud_training_data
  dbms=csv
  replace;
  getnames=yes;
run;

/* Verify the data was imported */
proc print data=modelcas.fraud_training_data (obs=10);
  title "First 10 rows of fraud_training_data";
run;

/* Get summary statistics */
proc contents data=modelcas.fraud_training_data;
  title "Structure of fraud_training_data";
run;

/* Display row count */
proc sql;
  select count(*) as total_rows from modelcas.fraud_training_data;
quit;

%put SUCCESS: fraud_training_data has been imported to SAS Viya;
%put The table is now available as: modelcas.fraud_training_data;
%put You can now use this table in Model Studio;


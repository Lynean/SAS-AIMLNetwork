/* ============================================================================
   Caller for Rule 50094.1 (ML_RULE_50094_1.sas) fallback scoring formula
   ============================================================================

   ML_RULE_50094_1.sas is a SAS Fraud Decisioning rule fragment (declare /
   try-catch / pmml.score / detection.Alert) written for that engine's rule
   editor, not standalone executable SAS -- it has no data step or PROC
   wrapper of its own. This caller exercises the rule's documented FALLBACK
   scoring path verbatim: the same logistic-regression coefficients and the
   same 0.70 / 0.60 / 0.40 decision thresholds the rule uses when its PMML
   model is unavailable, applied here as a plain DATA step over a sample of
   the repo's own fraud_training_data.csv rows.
   ============================================================================ */

/* 15-row sample of the repo's own fraud_training_data.csv, inlined (the
   bundle runner sends only script text, not sibling data files). */
data work.transactions;
  infile datalines dlm=',' dsd;
  input transaction_id target transaction_amount merchant_country $
        cardholder_country $ is_foreign transaction_hour account_age_days
        days_since_last txn_count_30days high_risk_amount high_risk_country
        new_account dormant_reactivation;
  datalines;
1998,0,62,MX,US,1,12,22,86,6,0,0,1,0
1843,1,493,NG,US,1,13,1686,7,12,0,1,0,0
1579,1,1921,KP,US,1,11,13,4,4,1,1,1,0
1588,0,24,US,US,0,19,2,15,15,0,0,1,0
1845,0,35,US,US,0,20,1263,14,4,0,0,0,0
1591,0,28,US,US,0,21,1465,89,5,0,0,0,1
1840,1,437,US,US,0,0,4,22,20,0,0,1,0
770,0,35,US,US,0,21,1247,2,7,0,0,0,0
1585,1,179,PH,US,1,17,601,5,6,0,1,0,0
870,0,32,US,US,0,16,3608,45,4,0,0,0,0
1572,1,1568,RU,US,1,15,747,3,8,1,1,0,0
53,1,21,PH,US,1,21,25,3,23,0,1,1,0
593,0,56,US,US,0,18,169,4,10,0,0,0,0
1582,1,489,PH,US,1,21,994,1,1,0,1,0,0
563,1,40,TH,US,1,18,17,20,2,0,1,1,0
;
run;

data work.scored;
  set work.transactions;

  /* Fallback Logistic Regression formula, transcribed from
     ML_RULE_50094_1.sas Step 1 (catch branch) */
  ml_fraud_score = 1.0 / (1.0 + exp(
     -(-2.5
       + 0.0003 * transaction_amount
       - 0.15 * transaction_hour
       - 0.001 * account_age_days
       + 0.08 * days_since_last
       + 0.05 * txn_count_30days
       + 0.60 * is_foreign
       + 0.55 * high_risk_amount
       + 0.45 * high_risk_country
       + 0.40 * new_account
       + 0.35 * dormant_reactivation
     )
  ));

  ml_fraud_score = max(0, min(1, ml_fraud_score));

  /* Rule 50094.1 Step 2: score-to-decision thresholds */
  if ml_fraud_score >= 0.70 then do;
     output_decision = 'ALERT';
     output_risk_level = 'CRITICAL';
  end;
  else if ml_fraud_score >= 0.60 then do;
     output_decision = 'REVIEW';
     output_risk_level = 'HIGH';
  end;
  else if ml_fraud_score >= 0.40 then do;
     output_decision = 'MONITOR';
     output_risk_level = 'MEDIUM';
  end;
  else do;
     output_decision = 'APPROVE';
     output_risk_level = 'LOW';
  end;

  output_ml_fraud_score = round(ml_fraud_score, 0.0001);
  output_rule_name = 'Rule 50094.1: ML Fraud Detection';
run;

title "Rule 50094.1 Fallback Scoring - Sample Transactions";
proc print data=work.scored;
  var transaction_id target output_ml_fraud_score output_decision output_risk_level;
run;

title "Decision Distribution (Fallback Formula)";
proc freq data=work.scored;
  tables output_decision / missing nocum;
run;

title "Score vs. Actual Fraud Label";
proc means data=work.scored n mean std min max;
  class target;
  var output_ml_fraud_score;
run;

title;

/* ============================================================================
   SYNTHETIC FRAUD TRANSACTION DATA FOR MODEL TRAINING
   ============================================================================

   This SAS program generates realistic synthetic fraud data for training
   ML-based fraud detection models in SAS Model Studio.

   Output: fraud_training_data.csv (2000 transactions)

   Features included:
   - Transaction amounts (varying by fraud/legitimate)
   - Merchant country (with high-risk countries overrepresented in fraud)
   - Cardholder country vs Merchant country (foreign indicators)
   - Time of day (fraud more likely at odd hours)
   - Days since account opening
   - Days since last transaction
   - Account age
   - Transaction count in past 30 days
   - Fraud label (TARGET = 1 for fraud, 0 for legitimate)

   ============================================================================ */

data fraud_training_data;
   call streaminit(12345); /* Set seed for reproducibility */

   do transaction_id = 1 to 2000;

      /* Step 1: Assign fraud indicator (40% fraud rate in training data) */
      is_fraud = (rand('uniform') < 0.40);

      /* Step 2: Transaction amount */
      if is_fraud then do;
         /* Fraud transactions: higher amounts, more concentrated at extremes */
         amount_dist = rand('uniform');
         if amount_dist < 0.30 then
            transaction_amount = round(rand('normal', 2000, 800)); /* High amount fraud */
         else if amount_dist < 0.60 then
            transaction_amount = round(rand('normal', 500, 200)); /* Mid-range fraud */
         else
            transaction_amount = round(rand('normal', 100, 50)); /* Low amount fraud (testing cards) */
         transaction_amount = max(10, abs(transaction_amount)); /* Ensure positive */
      end;
      else do;
         /* Legitimate transactions: lower average, more concentrated around mean */
         amount_dist = rand('uniform');
         if amount_dist < 0.10 then
            transaction_amount = round(rand('normal', 500, 200)); /* Few large purchases */
         else if amount_dist < 0.30 then
            transaction_amount = round(rand('normal', 150, 75)); /* Medium purchases */
         else
            transaction_amount = round(rand('normal', 50, 25)); /* Small purchases (most common) */
         transaction_amount = max(10, abs(transaction_amount));
      end;

      /* Step 3: Merchant country */
      if is_fraud then do;
         /* Fraud concentrated in high-risk countries */
         fraud_country_prob = rand('uniform');
         if fraud_country_prob < 0.15 then merchant_country = 'NG'; /* Nigeria */
         else if fraud_country_prob < 0.30 then merchant_country = 'CN'; /* China */
         else if fraud_country_prob < 0.45 then merchant_country = 'BR'; /* Brazil */
         else if fraud_country_prob < 0.60 then merchant_country = 'RU'; /* Russia */
         else if fraud_country_prob < 0.75 then merchant_country = 'KP'; /* North Korea */
         else if fraud_country_prob < 0.85 then merchant_country = 'IN'; /* India */
         else merchant_country = 'US'; /* Occasional US fraud */
      end;
      else do;
         /* Legitimate mostly domestic (US), some international */
         legit_country_prob = rand('uniform');
         if legit_country_prob < 0.70 then merchant_country = 'US'; /* Domestic */
         else if legit_country_prob < 0.80 then merchant_country = 'CA'; /* Canada */
         else if legit_country_prob < 0.90 then merchant_country = 'GB'; /* UK */
         else merchant_country = 'DE'; /* Germany */
      end;

      /* Step 4: Cardholder country (mostly US in this model) */
      cardholder_country = 'US'; /* Simplified: all US cardholders */

      /* Step 5: Is foreign transaction? */
      is_foreign = (merchant_country ^= cardholder_country);

      /* Step 6: Time of transaction (hour of day: 0-23) */
      if is_fraud then do;
         /* Fraud happens more at odd hours (night, early morning) */
         time_dist = rand('uniform');
         if time_dist < 0.50 then
            transaction_hour = round(rand('normal', 2, 3)); /* Night: midnight-3am */
         else
            transaction_hour = round(rand('normal', 14, 4)); /* Afternoon peak */
         transaction_hour = mod(abs(transaction_hour), 24); /* Ensure 0-23 */
      end;
      else do;
         /* Legitimate happens during business hours */
         transaction_hour = round(rand('normal', 14, 5)); /* Peak 9am-6pm */
         transaction_hour = max(0, min(23, transaction_hour));
      end;

      /* Step 7: Account age (days since opening) */
      if is_fraud then do;
         /* Fraud on newer accounts */
         account_age_days = round(rand('exponential') * 60 + 1); /* 1-120 days, skewed new */
      end;
      else do;
         /* Legitimate on all-age accounts, skewed older */
         age_dist = rand('uniform');
         if age_dist < 0.30 then
            account_age_days = round(rand('exponential') * 90 + 1); /* New accounts */
         else
            account_age_days = round(rand('uniform') * 1825 + 1); /* 0-5 years */
      end;

      /* Step 8: Days since last transaction */
      if is_fraud then do;
         /* Fraud after dormancy period */
         days_since_last = round(rand('exponential') * 15 + 1); /* 1-30 days */
      end;
      else do;
         /* Legitimate with recent activity */
         recent_dist = rand('uniform');
         if recent_dist < 0.60 then
            days_since_last = round(rand('uniform') * 3 + 1); /* Very recent: 1-3 days */
         else
            days_since_last = round(rand('uniform') * 30 + 1); /* Recent: 1-30 days */
      end;

      /* Step 9: Number of transactions in past 30 days */
      if is_fraud then do;
         /* Fraud: burst activity or testing */
         burst_dist = rand('uniform');
         if burst_dist < 0.40 then
            txn_count_30days = round(rand('poisson', 8)); /* Burst: 5-12 txns */
         else
            txn_count_30days = round(rand('poisson', 1)); /* Testing: 0-3 txns */
      end;
      else do;
         /* Legitimate: steady usage */
         txn_count_30days = round(rand('poisson', 3)); /* Normal: 1-5 txns */
      end;

      /* Step 10: Risk features */
      high_risk_amount = (transaction_amount > 1000);
      high_risk_country = merchant_country in ('NG', 'CN', 'BR', 'RU', 'KP');
      new_account = (account_age_days < 30);
      dormant_reactivation = (days_since_last > 14 and account_age_days > 180);

      /* Step 11: Set target variable */
      target = is_fraud;

      /* Step 12: Account ID (simulated) */
      account_id = 'ACC' || put(round(rand('uniform') * 10000), z5.);

      /* Step 13: Output observation */
      output;
   end;

   drop is_fraud amount_dist fraud_country_prob legit_country_prob time_dist age_dist
        recent_dist burst_dist;

run;

/* ============================================================================
   STEP 2: EXPORT TO CSV FOR SAS MODEL STUDIO IMPORT
   ============================================================================ */

proc export data=fraud_training_data
   outfile="D:\Works\Projects\SAS\SAS-AIMLNetwork\fraud_training_data.csv"
   dbms=csv
   replace;
run;

/* ============================================================================
   STEP 3: PRINT SUMMARY STATISTICS
   ============================================================================ */

title "Synthetic Fraud Training Data - Summary Statistics";

proc freq data=fraud_training_data;
   tables target;
   title "Target Distribution (Fraud = 1, Legitimate = 0)";
run;

proc means data=fraud_training_data n mean std min max;
   var transaction_amount account_age_days days_since_last txn_count_30days;
   class target;
   title "Numeric Features by Target";
run;

proc freq data=fraud_training_data;
   tables merchant_country * target / crosslist;
   title "Merchant Country Distribution by Target";
run;

proc means data=fraud_training_data mean;
   var high_risk_amount high_risk_country new_account dormant_reactivation;
   class target;
   title "Risk Indicator Prevalence by Target";
run;

title;

/* ============================================================================
   STEP 4: VERIFY DATA QUALITY
   ============================================================================ */

proc sql;
   select count(*) as total_rows,
          sum(target) as fraud_count,
          (sum(target) / count(*)) * 100 as fraud_percentage,
          count(distinct account_id) as unique_accounts
   from fraud_training_data;
   title "Data Quality Check";
quit;

/* ============================================================================
   OUTPUT SUMMARY
   ============================================================================

   Generated: fraud_training_data.csv

   Format: CSV with 14 columns
   Rows: 2,000 transactions
   Target: Fraud vs Legitimate (40% fraud rate)

   Columns:
   1. transaction_id - Unique identifier
   2. target - 0=Legitimate, 1=Fraud
   3. transaction_amount - Dollar amount
   4. merchant_country - Merchant location (ISO country code)
   5. cardholder_country - Cardholder location (always 'US')
   6. is_foreign - 1 if merchant != cardholder country
   7. transaction_hour - Hour of day (0-23)
   8. account_age_days - Days since account opening
   9. days_since_last - Days since last transaction
  10. txn_count_30days - Transactions in past 30 days
  11. high_risk_amount - 1 if amount > $1000
  12. high_risk_country - 1 if merchant in high-risk list
  13. new_account - 1 if account < 30 days old
  14. dormant_reactivation - 1 if dormant > 14 days then active
  15. account_id - Account identifier

   Next Steps:
   1. Run this SAS program to generate fraud_training_data.csv
   2. In SAS Model Studio: Click Import Data button
   3. Select fraud_training_data.csv
   4. Configure Data roles:
      - TARGET: 'target' (prediction target)
      - INPUTS: All numeric/categorical features
      - REJECTED: account_id, transaction_id (not predictive)
   5. Run Pipeline to train ML models

   ============================================================================ */

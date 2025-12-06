/* ============================================================================
   RULE 50094.1: ML FRAUD DETECTION SCORE
   ============================================================================

   Type: Machine Learning-based
   Source: SAS Model Studio
   Model: Fraud Detection ML Model (PMML)

   Purpose:
   Uses a trained ML model (Gradient Boosting, Logistic Regression, etc.)
   to generate a fraud probability score and convert to decision.

   Deployment:
   - In SAS Detection Definition Rules
   - Used in combination with Rules 50091.1, 50092.1, 50093.1
   - Final decision: Maximum severity from all 4 rules

   ============================================================================ */

/* Rule 50094.1: ML Fraud Detection Score */

declare numeric ml_fraud_score = 0;
declare varchar output_message = '';

/*
   Step 1: Call the ML Model
   ─────────────────────────
   The PMML model (exported from SAS Model Studio) is available in
   the detection rules environment. Call it to get fraud probability.
*/

/* For PMML-deployed models */
try do;
   ml_fraud_score = pmml.score(
      'Fraud Detection ML Model',  /* Model name as deployed */
      transaction_amount,          /* Input feature 1 */
      transaction_hour,            /* Input feature 2 */
      account_age_days,            /* Input feature 3 */
      days_since_last,             /* Input feature 4 */
      txn_count_30days,            /* Input feature 5 */
      is_foreign,                  /* Input feature 6 */
      high_risk_amount,            /* Input feature 7 */
      high_risk_country,           /* Input feature 8 */
      new_account,                 /* Input feature 9 */
      dormant_reactivation         /* Input feature 10 */
   );
end;
catch ex do;
   /* If PMML unavailable, fall back to Logistic Regression formula */
   /* (This is the backup scoring method) */
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
end;

/* Ensure score is between 0 and 1 */
ml_fraud_score = max(0, min(1, ml_fraud_score));

/*
   Step 2: Convert Score to Decision
   ──────────────────────────────────

   Fraud Probability Ranges:
   - 0.0 - 0.4 = APPROVE (low risk)
   - 0.4 - 0.6 = MONITOR (medium risk)
   - 0.6 - 0.7 = REVIEW (high risk)
   - 0.7 - 1.0 = ALERT (critical risk)

   These thresholds can be tuned based on:
   - Business requirements
   - False positive tolerance
   - Alert capacity
*/

if ml_fraud_score >= 0.70 then do;
   output_decision = 'ALERT';
   output_risk_level = 'CRITICAL';
   output_message = 'ML model predicts high fraud probability';
   detection.Alert();
end;
else if ml_fraud_score >= 0.60 then do;
   output_decision = 'REVIEW';
   output_risk_level = 'HIGH';
   output_message = 'ML model flags for analyst review';
   detection.Monitor();
end;
else if ml_fraud_score >= 0.40 then do;
   output_decision = 'MONITOR';
   output_risk_level = 'MEDIUM';
   output_message = 'ML model shows moderate fraud indicators';
   detection.Monitor();
end;
else do;
   output_decision = 'APPROVE';
   output_risk_level = 'LOW';
   output_message = 'ML model approves transaction';
   detection.Approve();
end;

/*
   Step 3: Log the Score for Monitoring
   ──────────────────────────────────────
   These variables are useful for:
   - Monitoring rule effectiveness
   - Calibrating thresholds
   - Debugging false positives
*/

output_ml_fraud_score = ml_fraud_score;
output_rule_name = 'Rule 50094.1: ML Fraud Detection';

/*
   Step 4: Combine with Other Rules
   ─────────────────────────────────

   IMPORTANT: This rule is ONE OF FOUR rules that work together:

   Rule 50091.1: High Transaction Velocity
   - Fast decision (< 1ms)
   - Catches obvious fraud (high amounts, foreign, etc.)
   - Few false positives

   Rule 50092.1: Transaction Anomaly Detector
   - Statistical approach (2-5ms)
   - Catches unusual patterns
   - More sophisticated than 50091.1

   Rule 50093.1: Fraud Ring Detector
   - Network analysis (batch, cached)
   - Catches organized fraud
   - Identifies account relationships

   Rule 50094.1: ML Fraud Detection (THIS RULE)
   - ML-based approach (5-10ms)
   - Trained on historical fraud patterns
   - Most sophisticated, catches subtle fraud

   DECISION COMBINATION:
   Final decision = MAXIMUM severity from all 4 rules

   Example:
   - Rule 50091.1 → APPROVE
   - Rule 50092.1 → REVIEW
   - Rule 50093.1 → MONITOR
   - Rule 50094.1 → ALERT
   ─────────────────────────
   Final → ALERT (maximum)

   This ensures that if ANY rule flags as critical, the transaction
   is escalated regardless of what other rules say.
*/

/*
   Step 5: Performance Monitoring
   ──────────────────────────────

   Metrics to track:
   1. Alert Rate: % transactions → ALERT decision
      Target: 1-3% of transactions
      If < 1%: Thresholds too high
      If > 5%: Thresholds too low or model overfitting

   2. Coverage: % of fraud caught
      Expected: 75-85% of real fraud
      Measured post-deployment against confirmed fraud

   3. False Positive Rate: % of APPROVE decisions that were fraud
      Target: < 20%
      If > 30%: Model needs retraining

   4. Model Stability: Does score distribution change over time?
      Monitor: Mean, std deviation of ml_fraud_score
      Action: Retrain model if distribution shifts >10%

   These metrics should be reviewed:
   - Daily (first week)
   - Weekly (first month)
   - Monthly (ongoing)
*/

/* ============================================================================
   IMPLEMENTATION NOTES
   ============================================================================

   1. PMML Model Deployment
      - Export model from SAS Model Studio as fraud_detection_model.xml
      - Upload to SAS Detection Definition > Models
      - Name it: 'Fraud Detection ML Model'
      - This rule will automatically find and use it

   2. Feature Availability
      All 10 input features must be available in the message:
      - transaction_amount: From transaction data
      - transaction_hour: From transaction timestamp
      - account_age_days: From account profile
      - days_since_last: From transaction history
      - txn_count_30days: From transaction history (rolling 30 days)
      - is_foreign: From merchant/cardholder countries
      - high_risk_amount: Derived (amount > $1000)
      - high_risk_country: Derived (country match)
      - new_account: Derived (age < 30 days)
      - dormant_reactivation: Derived (history + pattern)

      These can be:
      - Pre-calculated in message schema
      - Calculated in this rule
      - Calculated in ETL pipeline

   3. Fallback Scoring
      If PMML model unavailable, rule includes logistic regression
      formula as backup. Coefficients are estimates based on
      typical fraud patterns.

      Update coefficients after first month to match actual
      model performance.

   4. Threshold Tuning
      After first 2 weeks in Testing phase:
      - Analyze false positive distribution
      - Identify optimal threshold
      - Update: 0.70, 0.60, 0.40 values as needed
      - Re-deploy rule

   5. Model Retraining
      Recommended frequency:
      - Monthly: New patterns, seasonal fraud
      - Quarterly: Major updates
      - Immediately: If performance drops > 10%

      Trigger retraining if:
      - AUC drops below 0.80
      - False positive rate > 30%
      - Fraud patterns significantly change
      - New fraud types emerge

   6. Integration with Alert Triage
      This rule produces:
      - output_decision: Routed to Alert Triage
      - output_risk_level: For prioritization
      - output_message: For analyst review
      - output_ml_fraud_score: For detailed analysis

      Alert Triage should:
      - Route ALERT → High Priority queue
      - Route REVIEW → Medium Priority queue
      - Route MONITOR → Low Priority queue
      - Route APPROVE → No alert

   7. Compliance & Audit Trail
      Every decision is:
      - Logged with timestamp
      - Includes rule name and decision
      - Includes ml_fraud_score for audit
      - Traceable for regulatory review
      - Available for model monitoring

   8. Performance Expectations
      - Scoring latency: 5-10 ms per transaction
      - Accuracy: 80-85% (depends on training data)
      - Sensitivity (catch rate): 75-85%
      - Specificity (approval rate): 80-90%
      - False positive rate: 15-25%

      Real performance varies based on:
      - Quality of training data
      - Feature engineering
      - Threshold settings
      - Fraud environment changes

============================================================================ */

/* ============================================================================
   DEPLOYMENT CHECKLIST
   ============================================================================

   Before deploying this rule to Testing phase:

   [ ] ML model trained in SAS Model Studio
   [ ] Model exported to PMML format
   [ ] PMML file uploaded to SAS Detection Definition > Models
   [ ] Model name: 'Fraud Detection ML Model'
   [ ] All 10 features available in message schema
   [ ] Thresholds reviewed and approved (0.70, 0.60, 0.40)
   [ ] Fallback scoring formula prepared
   [ ] Alert routing configured in Alert Triage
   [ ] Monitoring dashboard created
   [ ] Team training completed
   [ ] Documentation updated
   [ ] Approval from Risk/Fraud management obtained

   After deploying to Testing:

   [ ] Monitor alert volume daily
   [ ] Collect false positive feedback from analysts
   [ ] Track fraud catch rate
   [ ] Monitor for model drift
   [ ] Document threshold adjustments
   [ ] Prepare for production deployment

============================================================================ */

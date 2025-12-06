# SAS Fraud Detection ML Model - Training Data

Complete fraud detection system using SAS Fraud Decisioning, SAS Model Studio, and ML-based fraud detection rules.

## Project Overview

This project implements a multi-layered fraud detection system:
- **Phase 1-2**: Decision rules created in SAS Fraud Decisioning (3 rules: high velocity, anomaly detection, fraud rings)
- **Phase 3**: ML model training and Rule 50094.1 (ML-based scoring)
- **Phase 4**: Testing and validation
- **Phase 5**: Production deployment

## Repository Contents

### Data Files
- **fraud_training_data.csv** - 2,000 synthetic fraud transactions
  - 38.1% fraud rate (763 fraud, 1,237 legitimate)
  - 14 columns: transaction features + fraud indicator
  - Ready for ML model training

### SAS Code Files
- **IMPORT_FROM_GITHUB.sas** - Download data from GitHub and import to SAS (RECOMMENDED)
- **LOAD_FRAUD_DATA.sas** - Alternative import method
- **ML_RULE_50094_1.sas** - ML-based fraud detection rule template
- **NETWORK_ANALYSIS_EXECUTABLE_CODE.sas** - Network analysis implementation

### Python Scripts
- **generate_fraud_data.py** - Generate synthetic fraud training data

## Quick Start - Import Data to SAS

### Step 1: Copy SAS Code
Copy this code into SAS Studio:

```sas
cas mysession sessopts=(cas="cas-shared-default" locale="en_US");
libname fraud_ml cas caslib="casuser";

filename frauddata url "https://raw.githubusercontent.com/Lynean/SAS-AIMLNetwork/main/fraud_training_data.csv";

proc import
  file=frauddata
  out=fraud_ml.fraud_training_data
  dbms=csv
  replace;
  getnames=yes;
run;

proc print data=fraud_ml.fraud_training_data (obs=10);
run;
```

### Step 2: Configure in Model Studio
1. Open Model Studio: https://poc.sas.env/SASModelStudio/
2. Go to: Fraud Detection ML Model > Data tab
3. Refresh data sources and select fraud_training_data
4. Configure data roles:
   - **TARGET**: target
   - **INPUT**: transaction_amount, transaction_hour, account_age_days, days_since_last, txn_count_30days, is_foreign, high_risk_amount, high_risk_country, new_account, dormant_reactivation
   - **REJECTED**: transaction_id, merchant_country, cardholder_country

### Step 3: Train Models
1. Go to Pipelines tab
2. Click "Run all pipelines"
3. Wait for 5 algorithms to train (2-5 minutes)

### Step 4: Deploy Rule 50094.1
1. Export best model from Pipeline Comparison
2. Create Rule 50094.1 in SAS Detection Definition
3. Promote all 4 rules to Testing phase

## Data Specification

### Columns (14 total)

| Column | Type | Description | Role |
|--------|------|-------------|------|
| transaction_id | Numeric | Unique transaction ID (1-2000) | REJECTED |
| target | Numeric | 0=Legitimate, 1=Fraud | TARGET |
| transaction_amount | Numeric | USD amount ($10-$3000+) | INPUT |
| merchant_country | Character | Country code | REJECTED |
| cardholder_country | Character | Country code | REJECTED |
| is_foreign | Binary | Foreign transaction flag | INPUT |
| transaction_hour | Numeric | Hour of day (0-23) | INPUT |
| account_age_days | Numeric | Days since account opened | INPUT |
| days_since_last | Numeric | Days since last transaction | INPUT |
| txn_count_30days | Numeric | Transactions in past 30 days | INPUT |
| high_risk_amount | Binary | Amount ≥ $1500 | INPUT |
| high_risk_country | Binary | High-risk country flag | INPUT |
| new_account | Binary | Account ≤ 30 days old | INPUT |
| dormant_reactivation | Binary | Dormant account reactivated | INPUT |

## Fraud Patterns in Data

The synthetic data includes realistic fraud patterns:
- **Higher transaction amounts** for fraud cases (mean: $1,500 vs $150)
- **Odd transaction hours** (typically 2-4 AM)
- **High-risk countries**: NG, CN, BR, RU, KP
- **New or dormant accounts** being misused
- **Foreign transactions** and unusual activity patterns

## Performance Expectations

Expected ML model performance (typical):
- ROC-AUC: 0.80-0.92
- Sensitivity: 75-85% (catch most fraud)
- Specificity: 90-95% (minimize false positives)

## Project Timeline

| Phase | Status | Timeline |
|-------|--------|----------|
| 1: Decision Rules | ✅ Complete | Done |
| 2: ML Infrastructure | ✅ Complete | Done |
| 3: Data & Model Training | 🔄 In Progress | This week |
| 4: Testing | ⏳ Pending | 2+ weeks |
| 5: Production | ⏳ Pending | Month 2 |

## Support

For issues or questions about the data or implementation, refer to:
- `PHASE_3_COMPLETE_SUMMARY.md` - Technical details
- `EXECUTION_PLAN_ML_TRAINING.md` - Step-by-step guide
- `SAS_FRAUD_DETECTION_IMPLEMENTATION_GUIDE.md` - Architecture reference

## License

Internal use - SAS Fraud Detection Project

---

**Repository**: https://github.com/Lynean/SAS-AIMLNetwork
**Last Updated**: December 6, 2025
**Status**: 55% Complete - Phase 3 Data Import Ready

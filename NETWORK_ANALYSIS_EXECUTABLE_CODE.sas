/*********************
 * SAS Network Analysis for Fraud Detection
 * Complete Executable Code
 * Purpose: Detect fraud rings through network analysis
 * Created: 2025-12-06
 *********************/

/****** STEP 1: CREATE SAMPLE TRANSACTION DATA ******/

data accounts_attributes;
  input account_id $ address $ phone_number $ email $ device_id $;
  datalines;
ACC001 "123 Main St" "555-1234" "john@email.com" "DEV001"
ACC002 "123 Main St" "555-1234" "jane@email.com" "DEV002"
ACC003 "456 Oak Ave" "555-5678" "bob@email.com" "DEV003"
ACC004 "789 Elm Rd" "555-1234" "alice@email.com" "DEV004"
ACC005 "123 Main St" "555-9999" "mike@email.com" "DEV005"
ACC006 "999 Fraud Way" "555-4444" "scammer1@email.com" "DEV006"
ACC007 "999 Fraud Way" "555-4444" "scammer2@email.com" "DEV007"
ACC008 "111 Clean Blvd" "555-8888" "clean@email.com" "DEV008"
ACC009 "999 Fraud Way" "555-4444" "scammer3@email.com" "DEV009"
ACC010 "111 Clean Blvd" "555-8888" "another_clean@email.com" "DEV010"
;
run;

data accounts_transactions;
  input account_id $ transaction_id $ amount merchant_country $ transaction_date yymmdd10.;
  datalines;
ACC001 TXN001 1500 NG 2025-12-01
ACC002 TXN002 2000 CN 2025-12-02
ACC003 TXN003 300 US 2025-12-03
ACC004 TXN004 1800 BR 2025-12-04
ACC005 TXN005 2500 NG 2025-12-05
ACC006 TXN006 3000 NG 2025-12-01
ACC007 TXN007 2800 CN 2025-12-02
ACC008 TXN008 150 US 2025-12-03
ACC009 TXN009 3500 NG 2025-12-01
ACC010 TXN010 200 US 2025-12-05
;
run;

proc print data=accounts_attributes;
  title "Accounts and Their Attributes";
run;

proc print data=accounts_transactions;
  title "Transaction Data";
run;


/****** STEP 2: BUILD NETWORK EDGES ******/

/* 2A: Create edges for accounts sharing addresses */
proc sort data=accounts_attributes;
  by address account_id;
run;

data address_edges;
  set accounts_attributes;
  by address;

  if _n_ = 1 then do;
    call execute('data _address_pairs; set accounts_attributes; by address; if not first.address; prev_account = lag(account_id); output; run;');
  end;
run;

/* Simpler approach: use SQL to find pairs */
proc sql;
  create table address_edges as
  select
    a.account_id as from_account,
    b.account_id as to_account,
    a.address,
    "SHARED_ADDRESS" as edge_type,
    1 as edge_weight
  from accounts_attributes a
  inner join accounts_attributes b
  on a.address = b.address
  and a.account_id < b.account_id;
quit;

/* 2B: Create edges for accounts sharing phones */
proc sql;
  create table phone_edges as
  select
    a.account_id as from_account,
    b.account_id as to_account,
    a.phone_number,
    "SHARED_PHONE" as edge_type,
    2 as edge_weight
  from accounts_attributes a
  inner join accounts_attributes b
  on a.phone_number = b.phone_number
  and a.account_id < b.account_id;
quit;

/* 2C: Combine all edges */
data all_edges;
  set address_edges phone_edges;

  /* Remove rows without valid edges */
  if from_account ne "";

  /* Normalize: ensure from < to */
  if from_account > to_account then do;
    temp = from_account;
    from_account = to_account;
    to_account = temp;
  end;

  /* Remove duplicates */
  drop address phone_number;

run;

/* Remove duplicate edges */
proc sort data=all_edges nodupkey;
  by from_account to_account;
run;

proc print data=all_edges;
  title "Network Edges (Accounts Sharing Attributes)";
run;

/* Get count of edges */
proc sql;
  select count(*) as total_edges from all_edges;
quit;


/****** STEP 3: IDENTIFY CONNECTED COMPONENTS ******/

/* Method: Create adjacency list and iteratively assign components */

/* Step 3A: Create full adjacency (bidirectional) */
proc sql;
  create table adjacency as
  select from_account as account_a, to_account as account_b
  from all_edges
  union all
  select to_account as account_a, from_account as account_b
  from all_edges;
quit;

/* Step 3B: Initialize component assignment */
data components;
  set accounts_attributes (keep=account_id);
  rename account_id = account_id;
  component_id = account_id;
  current_min = account_id;
run;

/* Step 3C: Iteratively propagate minimum component ID */
%macro propagate_components(iterations=10);
  %do i = 1 %to &iterations;

    proc sql;
      create table components_new as
      select
        a.account_id,
        min(a.current_min, coalesce(b.current_min, a.current_min)) as current_min
      from components a
      left join (
        select account_a, min(current_min) as current_min
        from adjacency c
        inner join components d on c.account_b = d.account_id
        group by account_a
      ) b on a.account_id = b.account_a
      group by a.account_id;
    quit;

    data components;
      set components_new;
    run;

  %end;
%mend;

%propagate_components(iterations=5);

/* Step 3D: Assign final component IDs */
data components_final;
  set components;
  component_id = current_min;
  keep account_id component_id;
run;

proc print data=components_final;
  title "Components Assignment (Before Counting Size)";
run;

/* Step 3E: Count component sizes */
proc sql;
  create table component_info as
  select
    component_id,
    count(*) as component_size,
    max(account_id) as sample_account
  from components_final
  group by component_id
  order by component_size desc;
quit;

proc print data=component_info;
  title "Connected Components (Fraud Rings)";
run;

/* Step 3F: Merge component sizes back */
data components_with_size;
  merge
    components_final (in=a)
    component_info (in=b keep=component_id component_size);
  by component_id;
  if a;
run;

proc print data=components_with_size;
  title "Accounts with Component Information";
  var account_id component_id component_size;
run;


/****** STEP 4: ANALYZE COMPONENT CHARACTERISTICS ******/

/* Merge with transaction data to get component risk profile */
proc sql;
  create table component_analysis as
  select
    a.account_id,
    a.component_id,
    a.component_size,
    b.amount,
    b.merchant_country,
    b.transaction_date
  from components_with_size a
  left join accounts_transactions b on a.account_id = b.account_id;
quit;

proc print data=component_analysis;
  title "Component Transaction Analysis";
run;

/* Get component-level aggregates */
proc sql;
  create table component_stats as
  select
    component_id,
    component_size,
    count(*) as num_transactions,
    sum(amount) as total_amount,
    avg(amount) as avg_amount,
    max(amount) as max_amount
  from component_analysis
  group by component_id, component_size
  order by total_amount desc;
quit;

proc print data=component_stats;
  title "Component Summary Statistics";
run;


/****** STEP 5: CALCULATE FRAUD RING RISK SCORES ******/

data fraud_ring_risk;
  merge
    component_analysis (in=a)
    component_info (in=b keep=component_id component_size);
  by component_id;

  if a;

  /* Initialize risk score */
  ring_risk_score = 0;

  /* FACTOR 1: Component Size (multiple accounts = stronger fraud signal) */
  if component_size >= 5 then
    ring_risk_score = ring_risk_score + 0.40;
  else if component_size >= 4 then
    ring_risk_score = ring_risk_score + 0.35;
  else if component_size >= 3 then
    ring_risk_score = ring_risk_score + 0.20;
  else if component_size >= 2 then
    ring_risk_score = ring_risk_score + 0.10;

  /* FACTOR 2: High-Risk Countries */
  if merchant_country in ('NG', 'CN', 'BR', 'RU', 'KP') then
    ring_risk_score = ring_risk_score + 0.25;
  else if merchant_country in ('TH', 'ID', 'PH', 'VN') then
    ring_risk_score = ring_risk_score + 0.15;

  /* FACTOR 3: High Transaction Amounts */
  if amount >= 3000 then
    ring_risk_score = ring_risk_score + 0.35;
  else if amount >= 2000 then
    ring_risk_score = ring_risk_score + 0.20;
  else if amount >= 1500 then
    ring_risk_score = ring_risk_score + 0.10;

  /* Cap score at 1.0 */
  ring_risk_score = min(ring_risk_score, 1.0);

  /* DECISION LOGIC */
  if ring_risk_score >= 0.70 then do;
    ring_decision = 'ALERT';
    ring_severity = 'CRITICAL';
  end;
  else if ring_risk_score >= 0.50 then do;
    ring_decision = 'REVIEW';
    ring_severity = 'HIGH';
  end;
  else if ring_risk_score >= 0.30 then do;
    ring_decision = 'MONITOR';
    ring_severity = 'MEDIUM';
  end;
  else do;
    ring_decision = 'APPROVE';
    ring_severity = 'LOW';
  end;

run;

proc print data=fraud_ring_risk;
  title "Fraud Ring Risk Scoring Results";
  var account_id component_id component_size amount merchant_country
      ring_risk_score ring_decision ring_severity;
run;


/****** STEP 6: SUMMARY REPORTS ******/

/* Report 1: Risk Distribution */
proc freq data=fraud_ring_risk;
  title "Alert Distribution by Network Analysis";
  tables ring_decision / missing nocum nopercent;
run;

/* Report 2: Component Summary */
proc sql;
  create table component_summary as
  select
    component_id,
    component_size,
    count(*) as num_accounts_with_txns,
    count(distinct merchant_country) as num_countries,
    sum(amount) as total_fraud_amount,
    avg(ring_risk_score) as avg_ring_risk,
    max(ring_risk_score) as max_ring_risk,
    max(ring_decision) as component_decision
  from fraud_ring_risk
  group by component_id, component_size
  order by avg_ring_risk desc;
quit;

proc print data=component_summary;
  title "Fraud Ring Summary Report";
run;

/* Report 3: High-Risk Accounts */
data high_risk_accounts;
  set fraud_ring_risk;
  where ring_decision in ('ALERT', 'REVIEW');
run;

proc print data=high_risk_accounts;
  title "High-Risk Accounts (ALERT and REVIEW)";
  var account_id component_id component_size amount merchant_country
      ring_risk_score ring_decision;
run;

proc sql;
  select count(*) as num_high_risk_accounts from high_risk_accounts;
quit;

/* Report 4: Risk Score Distribution */
proc means data=fraud_ring_risk n mean std min max;
  title "Ring Risk Score Statistics";
  var ring_risk_score;
run;

/* Report 5: Component Size Distribution */
proc freq data=fraud_ring_risk;
  title "Distribution by Component Size";
  tables component_size / missing;
run;


/****** STEP 7: IDENTIFY RING LEADERS (Centrality) ******/

/* Find most connected accounts */
proc sql;
  create table account_connections as
  select
    account_id,
    component_id,
    count(*) as num_shared_attributes
  from (
    select account_id, component_id, address as shared_attr from fraud_ring_risk
    union all
    select account_id, component_id, merchant_country as shared_attr from fraud_ring_risk
  )
  group by account_id, component_id;
quit;

proc sort data=account_connections;
  by component_id descending num_shared_attributes;
run;

proc print data=account_connections;
  title "Account Centrality (Connection Count)";
run;


/****** STEP 8: CREATE FINAL ENRICHED DATASET ******/

/* This would be used to enrich the Card Fraud message schema */
data final_enriched_transactions;
  merge
    fraud_ring_risk (in=a)
    account_connections (in=b keep=account_id num_shared_attributes);
  by account_id;

  if a;

  /* Add network analysis results as new fields in message schema */
  network_component_id = component_id;
  network_component_size = component_size;
  network_risk_score = ring_risk_score;
  network_decision = ring_decision;
  network_severity = ring_severity;
  network_centrality = num_shared_attributes;

  keep account_id transaction_id amount merchant_country
       network_component_id network_component_size network_risk_score
       network_decision network_severity network_centrality;

run;

proc print data=final_enriched_transactions;
  title "Final Enriched Dataset for Fraud Decisioning";
run;


/****** STEP 9: EXPORT FOR INTEGRATION ******/

/* Export to CSV for integration with SAS Fraud Decisioning */
proc export data=final_enriched_transactions
  outfile="D:\Works\Projects\SAS\SAS-AIMLNetwork\network_enrichment_scores.csv"
  dbms=csv replace;
run;

/* Export risk summary */
proc export data=component_summary
  outfile="D:\Works\Projects\SAS\SAS-AIMLNetwork\fraud_ring_components.csv"
  dbms=csv replace;
run;

proc export data=fraud_ring_risk
  outfile="D:\Works\Projects\SAS\SAS-AIMLNetwork\account_network_risk.csv"
  dbms=csv replace;
run;


/****** STEP 10: NETWORK VISUALIZATION (GraphViz DOT Format) ******/

/* Generate DOT format for network visualization */
filename dotfile "D:\Works\Projects\SAS\SAS-AIMLNetwork\fraud_network.dot";

data _null_;
  file dotfile;

  put "graph fraud_network {";
  put "  rankdir=LR;";
  put "  node [shape=circle, style=filled];";
  put "";

  /* Add nodes with colors based on risk */
  set fraud_ring_risk end=eof;

  if _n_ = 1 then do;
    /* Add nodes */
    set fraud_ring_risk nobs=nobs end=end_nodes;
    if ring_severity = 'CRITICAL' then
      put "  """ account_id """ [color=red, fillcolor=red, fontcolor=white, label=""" account_id """];";
    else if ring_severity = 'HIGH' then
      put "  """ account_id """ [color=orange, fillcolor=orange, fontcolor=white, label=""" account_id """];";
    else if ring_severity = 'MEDIUM' then
      put "  """ account_id """ [color=yellow, fillcolor=yellow, label=""" account_id """];";
    else
      put "  """ account_id """ [color=green, fillcolor=lightgreen, label=""" account_id """];";
  end;

run;

/* Read edges and add to DOT */
data _null_;
  file dotfile mod;
  set all_edges;

  put "  """ from_account """ -- """ to_account """ [label=""" edge_type """];";

run;

data _null_;
  file dotfile mod;
  put "}";
run;

proc print log;
  title "GraphViz DOT file created at: D:\Works\Projects\SAS\SAS-AIMLNetwork\fraud_network.dot";
run;


/****** SUMMARY AND NEXT STEPS ******/

title "Network Analysis Execution Complete";
proc print;
  put "";
  put "========================================";
  put "Network Analysis Execution Summary";
  put "========================================";
  put "";
  put "Step 1: ✓ Sample data created";
  put "Step 2: ✓ Network edges built";
  put "Step 3: ✓ Connected components identified";
  put "Step 4: ✓ Component characteristics analyzed";
  put "Step 5: ✓ Fraud ring risk scores calculated";
  put "Step 6: ✓ Summary reports generated";
  put "Step 7: ✓ Ring leaders identified";
  put "Step 8: ✓ Final enriched dataset created";
  put "Step 9: ✓ Data exported for integration";
  put "Step 10: ✓ Network visualization generated";
  put "";
  put "Output Files Created:";
  put "  - network_enrichment_scores.csv";
  put "  - fraud_ring_components.csv";
  put "  - account_network_risk.csv";
  put "  - fraud_network.dot";
  put "";
  put "Next Steps:";
  put "1. Review high-risk accounts in the reports above";
  put "2. Import enrichment scores into Card Fraud message schema";
  put "3. Create Rule 50093.1 (Fraud Ring Detector) in SAS Fraud Decisioning";
  put "4. Deploy rule to Testing phase";
  put "5. Monitor results in Alert Triage system";
  put "";
  put "========================================";
run;

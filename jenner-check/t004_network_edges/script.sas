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


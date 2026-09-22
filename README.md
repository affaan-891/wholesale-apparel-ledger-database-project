# Wholesale Apparel Multi-Tier Ledger & Udhaar Management System

[![MySQL Version](https://img.shields.io/badge/MySQL-8.0%2B-blue.svg?logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Storage Engine](https://img.shields.io/badge/Engine-InnoDB-success.svg)](https://dev.mysql.com/doc/refman/8.0/en/innodb-storage-engine.html)
[![Normalization](https://img.shields.io/badge/Design-3NF%20Compliant-orange.svg)](docs/ERD.md)
[![Accounting](https://img.shields.io/badge/Accounting-Double--Entry%20GAAP-purple.svg)](database/01_schema.sql)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An open-source, production-grade academic database repository modeled for university computer science and software engineering students. Built specifically to satisfy university DBMS grading rubrics (3NF normalization, zero redundancy, immutable double-entry ledger bookkeeping, customer credit-limit enforcement triggers, batch-wise size/color inventory management, debt aging schedule queries with explicit ACID transactions, analytical views, and viva defense materials).

---

## Repository Quick Links
- **Clone URL**: `git clone https://github.com/affaan-891/wholesale-apparel-ledger-database-project.git`
- **ERD & Data Dictionary**: [`docs/ERD.md`](docs/ERD.md)
- **University Viva Voce Preparation Guide**: [`docs/VIVA_QUESTIONS.md`](docs/VIVA_QUESTIONS.md)
- **Database Scripts**:
  1. [`database/01_schema.sql`](database/01_schema.sql) - 11 Normalized Tables (3NF DDL)
  2. [`database/02_triggers.sql`](database/02_triggers.sql) - Credit Enforcement & Stock Triggers
  3. [`database/03_procedures.sql`](database/03_procedures.sql) - ACID Invoice Posting & FIFO Payment Stored Procedures
  4. [`database/04_views_and_queries.sql`](database/04_views_and_queries.sql) - Accounts Receivable Aging Views & Viva Queries
  5. [`database/05_seed_data.sql`](database/05_seed_data.sql) - Commercial Apparel Seed Dataset

---

## System Architecture

```text
wholesale-apparel-ledger-database-project/
├── database/
│   ├── 01_schema.sql             # 11 3NF normalized tables with check constraints & indexes
│   ├── 02_triggers.sql           # Business triggers (Credit ceiling check, stock decrement)
│   ├── 03_procedures.sql         # ACID stored procedures (Pessimistic locking, FIFO settlement)
│   ├── 04_views_and_queries.sql  # Dynamic aging views & 5 complex viva evaluation queries
│   └── 05_seed_data.sql          # Seed dataset with accounts, customers, articles, batches, vouchers
├── docs/
│   ├── ERD.md                    # Visual Mermaid Crow's Foot diagram & data dictionary
│   └── VIVA_QUESTIONS.md         # 10 rigorous viva questions with examiner-grade defense answers
└── README.md
```

---

## Key Domain Highlights

### 1. 3NF Normalized Relational Schema
- **11 Relational Entities**: `chart_of_accounts`, `customer_profiles`, `product_articles`, `article_variants`, `inventory_batches`, `sales_invoices`, `sales_invoice_items`, `general_journal_vouchers`, `journal_ledger_entries`, `customer_receipts`, and `credit_audit_logs`.
- **Zero Redundancy**: Apparel attributes decompose across Design Article $\rightarrow$ Variant Matrix (Color/Size) $\rightarrow$ Physical Inventory Lot.

### 2. Immutable Double-Entry Ledger Bookkeeping
- Every commercial event atomically posts an immutable voucher to `general_journal_vouchers` and dual debit/credit entries to `journal_ledger_entries`.
- Customer accounts in `customer_profiles` map 1:1 with specific Accounts Receivable sub-ledger accounts in the `chart_of_accounts`.
- Enforces fundamental accounting identity:
  $$\sum \text{Debits} = \sum \text{Credits}$$

### 3. Automated Credit-Limit Enforcement
- `trg_enforce_customer_credit_limit` intercepts invoice generation before insertion.
- Calculates live customer debt directly from the double-entry sub-ledger (`SUM(debit) - SUM(credit)`).
- Rejects any invoice attempting to breach the authorized credit ceiling via `SIGNAL SQLSTATE '45000'`.

### 4. Dynamic Accounts Receivable Aging Schedule
- `vw_customer_aging_schedule` computes real-time aging debt buckets using date math (`DATEDIFF(CURRENT_DATE, si.invoice_date)`):
  - **0 - 30 Days**: Current Debt
  - **31 - 60 Days**: Overdue Debt
  - **61 - 90 Days**: Delinquent Debt
  - **> 90 Days**: High Default Risk

### 5. FIFO Debt Amortization Stored Procedure
- `sp_record_customer_payment` utilizes database cursors to apply customer lump-sum receipts against their oldest unsettled invoices in chronological First-In, First-Out sequence.

---

## Quickstart & Installation

### Option A: MySQL Command-Line Client (CLI)

```bash
# 1. Clone the repository
git clone https://github.com/affaan-891/wholesale-apparel-ledger-database-project.git
cd wholesale-apparel-ledger-database-project

# 2. Execute scripts in dependency order
mysql -u root -p < database/01_schema.sql
mysql -u root -p < database/02_triggers.sql
mysql -u root -p < database/03_procedures.sql
mysql -u root -p < database/04_views_and_queries.sql
mysql -u root -p < database/05_seed_data.sql
```

### Option B: phpMyAdmin / MySQL Workbench
1. Open **phpMyAdmin** or **MySQL Workbench**.
2. Create a new database or allow `01_schema.sql` to initialize `wholesale_ledger_db`.
3. Sequentially import `01_schema.sql` $\rightarrow$ `02_triggers.sql` $\rightarrow$ `03_procedures.sql` $\rightarrow$ `04_views_and_queries.sql` $\rightarrow$ `05_seed_data.sql`.

---

## Sample Analytical Outputs

### 1. Accounts Receivable Aging Schedule (`vw_customer_aging_schedule`)
```sql
SELECT business_name, city, credit_limit, total_outstanding_debt, 
       aging_bucket_0_to_30_days, aging_bucket_31_to_60_days, 
       aging_bucket_61_to_90_days, aging_bucket_over_90_days
FROM vw_customer_aging_schedule;
```
| business_name | city | credit_limit | total_outstanding_debt | 0-30 Days | 31-60 Days | 61-90 Days | >90 Days |
|---|---|---|---|---|---|---|---|
| Al-Rahim Cloth Emporium | Lahore | 1,500,000.00 | 116,000.00 | 0.00 | 116,000.00 | 0.00 | 0.00 |
| Madina Fabrics Wholesale | Faisalabad | 1,200,000.00 | 436,000.00 | 0.00 | 306,000.00 | 0.00 | 130,000.00 |
| Karachi Denim House | Karachi | 2,000,000.00 | 163,000.00 | 0.00 | 163,000.00 | 0.00 | 0.00 |
| Faisalabad Yarn & Stitch | Faisalabad | 800,000.00 | 214,500.00 | 142,000.00 | 0.00 | 72,500.00 | 0.00 |
| Gujranwala Garment Traders| Gujranwala | 900,000.00 | 462,500.00 | 180,500.00 | 0.00 | 282,000.00 | 0.00 |
| Rawalpindi Outfitters Ltd | Rawalpindi | 1,000,000.00 | 610,000.00 | 350,000.00 | 0.00 | 260,000.00 | 0.00 |

### 2. Batch Inventory Valuation (`vw_batch_inventory_valuation`)
```sql
SELECT article_code, article_name, sku, lot_number, available_pieces, 
       total_inventory_cost_value, potential_wholesale_realization, stock_health_status
FROM vw_batch_inventory_valuation
LIMIT 5;
```

---

## Testing Business Rules & Triggers

### Test 1: Customer Credit Ceiling Breach
Attempting to create an invoice that exceeds the customer's authorized limit:
```sql
-- Customer 4 has credit limit of 800,000 and current debt > 200,000
-- Attempting an invoice of 700,000 will breach the ceiling:
INSERT INTO sales_invoices (invoice_number, customer_id, invoice_date, gross_amount, special_discount, net_payable, paid_amount, invoice_status)
VALUES ('INV-TEST-FAIL', 4, CURRENT_DATE, 700000.00, 0.00, 700000.00, 0.00, 'Unpaid');

-- Result:
-- ERROR 1644 (45000): Credit Limit Breach: Outstanding balance plus new invoice exceeds authorized credit ceiling.
```

### Test 2: Inventory Stockout Protection
Attempting to allocate more stock than physically available in a production lot:
```sql
-- Attempting to bill 10,000 pieces on batch 1 (only 380 pieces available)
INSERT INTO sales_invoice_items (invoice_id, batch_id, quantity_pieces, unit_wholesale_price, line_total)
VALUES (1, 1, 10000, 1850.00, 18500000.00);

-- Result:
-- ERROR 1644 (45000): Stock Shortage: Insufficient inventory pieces available in the selected apparel batch.
```

---

## Git Setup & Push Instructions

To push this repository to GitHub:

```powershell
# 1. Initialize git
git init

# 2. Add remote repository
git remote add origin https://github.com/affaan-891/wholesale-apparel-ledger-database-project.git

# 3. Pull existing files (like LICENSE) if already on GitHub
git pull origin main --allow-unrelated-histories

# 4. Stage all files and commit
git add .
git commit -m "feat: complete wholesale apparel ledger DBMS project with double-entry accounting, credit limit triggers, aging views and ERD"

# 5. Push to GitHub
git branch -M main
git push -u origin main
```

---

## Author & Academic Attribution
- **Repository**: [wholesale-apparel-ledger-database-project](https://github.com/affaan-891/wholesale-apparel-ledger-database-project)
- **Author**: Muhammad Affaan ([@affaan-891](https://github.com/affaan-891))
- **Course Focus**: Database Management Systems (CS320 / CS304), Advanced Relational Modeling & Transaction Management.

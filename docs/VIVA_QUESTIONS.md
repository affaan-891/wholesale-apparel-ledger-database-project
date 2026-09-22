# University DBMS Viva Voce Defense Guide

## Wholesale Apparel Multi-Tier Ledger & Udhaar Management System

This document contains 10 rigorous, in-depth technical viva questions designed to prepare students for final semester DBMS project evaluations, lab vivas, and software engineering technical interviews.

---

### Q1: Why can't MySQL enforce double-entry equality (`SUM(debit) = SUM(credit)`) directly in an `AFTER INSERT` row-level trigger on `journal_ledger_entries`? How does this project solve it?
**Examiner's Angle:** Tests understanding of SQL engine execution lifecycles, mutating table limitations (MySQL Error 1442), and architectural design tradeoffs.

**Defense Answer:**
In MySQL, row-level triggers execute atomically for each inserted row. If an `AFTER INSERT` trigger on `journal_ledger_entries` attempts to execute `SELECT SUM(debit), SUM(credit) FROM journal_ledger_entries WHERE voucher_id = NEW.voucher_id`, MySQL rejects the operation with **Error 1442 (HY000): Can't update/read table in stored function/trigger because it is already being used by statement which invoked this stored function/trigger**.

Furthermore, from an accounting domain standpoint, double-entry vouchers are inherently **multi-legged** (consisting of 2, 3, 4, or more rows for sales, discounts, taxes, and COGS). During row-by-row insertion, interim individual rows are mathematically unbalanced:
1. Line 1: Debit Accounts Receivable = 180,000 (Credits = 0) $\rightarrow$ *Unbalanced*
2. Line 2: Credit Sales Revenue = 180,000 $\rightarrow$ *Now Balanced*

**Our Architectural Solution:**
1. **Row-Level Mutual Exclusion**: Enforced via DDL `CHECK ((debit > 0 AND credit = 0) OR (debit = 0 AND credit > 0))`.
2. **Atomic Procedure Validation**: Double-entry verification is encapsulated inside the ACID transaction stored procedure `sp_post_sales_invoice_with_ledger`. The procedure calls `sp_verify_voucher_balance(v_voucher_id)` after all legs are written but *before* the transaction commits. If debits do not match credits, it triggers `SIGNAL SQLSTATE '45000'` which forces an immediate `ROLLBACK`.

---

### Q2: Prove that the schema is strictly in Third Normal Form (3NF). Provide a concrete functional dependency example from the schema.
**Examiner's Angle:** Evaluates formal normalization theory, functional dependencies ($FDs$), and candidate key analysis.

**Defense Answer:**
A schema is in 3NF if and only if for every non-trivial functional dependency $X \rightarrow Y$:
1. $X$ is a superkey, OR
2. $Y$ is a prime attribute (part of a candidate key).

**Proof Breakdown:**
1. **1NF**: Every column contains atomic scalar values. No repeating groups (line items are split into `sales_invoice_items`).
2. **2NF**: No partial dependencies on any composite candidate key. In `article_variants`, candidate key is `(article_id, color, size)`. All attributes (`sku`) depend on the complete key.
3. **3NF**: Zero transitive dependencies ($X \rightarrow Y$ and $Y \rightarrow Z$).
   - *Example Violation Avoided*: In a de-normalized system, `sales_invoices` might store `customer_city` or `customer_credit_limit`. That would induce the transitive dependency:
     $$\text{invoice\_id} \rightarrow \text{customer\_id} \rightarrow \text{customer\_city}$$
     In our schema, `customer_city` and `credit_limit` are strictly isolated in `customer_profiles`. `sales_invoices` only contains `customer_id` (FK), eliminating update anomalies.
   - *Inventory Cost Example*: Similarly, `manufacturing_cost` depends on `batch_id`, not on `item_id` or `article_id`. Hence, it resides in `inventory_batches`.

---

### Q3: Why is pessimistic locking (`SELECT ... FOR UPDATE`) mandatory in `sp_post_sales_invoice_with_ledger`? What concurrency race condition would occur without it?
**Examiner's Angle:** Assesses transaction isolation levels, concurrency control, race conditions, and financial over-allocation bugs.

**Defense Answer:**
Under standard `READ COMMITTED` or `REPEATABLE READ` isolation without locking:
Imagine Customer A has a credit limit of PKR 1,000,000 and current debt of PKR 800,000 (available credit = PKR 200,000).
1. **Thread 1 (Cashier 1)**: Submits Invoice 1 for PKR 150,000. It reads `current_debt = 800,000`. $800,000 + 150,000 \le 1,000,000$ (Approved).
2. **Thread 2 (Cashier 2)**: Simultaneously submits Invoice 2 for PKR 120,000. It reads `current_debt = 800,000`. $800,000 + 120,000 \le 1,000,000$ (Approved).
3. Both threads insert their invoices concurrently. Total debt jumps to PKR 1,070,000, causing a **silent credit limit breach of PKR 70,000**.

**How `FOR UPDATE` Solves This:**
In `sp_post_sales_invoice_with_ledger`:
```sql
SELECT account_id, credit_limit, status
  FROM customer_profiles
 WHERE customer_id = p_customer_id
   FOR UPDATE;
```
This acquires an exclusive write lock on the customer's row. Thread 2 is forced to wait until Thread 1 commits its invoice and ledger entries. When Thread 2 acquires the lock, it reads the updated debt (PKR 950,000) and immediately aborts with `Credit Limit Breach`. The exact same pessimistic lock protects `inventory_batches.available_pieces` against double-selling.

---

### Q4: How does the system guarantee the ACID properties during an invoice creation cycle?
**Examiner's Angle:** Evaluates fundamental transaction management and failure recovery mechanisms.

**Defense Answer:**
In `sp_post_sales_invoice_with_ledger`:
- **Atomicity**: The entire workflow (invoice record, multiple line items, inventory stock decrements, general journal voucher, and multiple ledger entries) is enclosed between `START TRANSACTION` and `COMMIT`. An `EXIT HANDLER FOR SQLEXCEPTION` executes `ROLLBACK; RESIGNAL;` on any failure. If inventory stockout or voucher imbalance occurs on step 9, steps 1 through 8 are completely undone.
- **Consistency**: All database invariants (`CHECK` constraints, credit limits via triggers, foreign key constraints, balanced debit/credit sums) are validated before commit.
- **Isolation**: Handled via `InnoDB` row-level pessimistic locks (`SELECT ... FOR UPDATE`), preventing dirty reads, non-repeatable reads, and phantom writes.
- **Durability**: Upon `COMMIT`, InnoDB's Write-Ahead Logging (WAL) flushes changes to the `ib_logfile` (redo log), guaranteeing that committed transactions survive power outages or server crashes.

---

### Q5: Why is the Accounts Receivable Aging Schedule implemented as a dynamic View (`DATEDIFF`) rather than storing precalculated aging bucket columns in the table?
**Examiner's Angle:** Addresses data staleness, temporal arithmetic, and the Single Source of Truth principle.

**Defense Answer:**
Aging is an intrinsically **time-variant metric**. An unpaid invoice that is 29 days old today will automatically become 30 days old tomorrow and 31 days old (moving from `0-30 Days` to `31-60 Days`) the following day without any physical transaction occurring in the database.

If aging buckets were stored as persistent columns:
1. The database would require expensive nightly batch cron jobs or daemon processes to scan and update millions of rows every midnight.
2. If the batch job failed, financial reports would display stale, inaccurate risk classifications.
3. It violates the database design principle against storing transient derived data.

By implementing `vw_customer_aging_schedule` using dynamic `DATEDIFF(CURRENT_DATE, si.invoice_date)`, the calculation evaluates against the server's real-time clock at query execution time. Unpaid balances are always 100% up-to-date.

---

### Q6: What is the architectural purpose of linking `customer_profiles` to `chart_of_accounts` via a 1:1 Foreign Key (`account_id`)?
**Examiner's Angle:** Explores enterprise ERP architecture, general ledger sub-ledger integration, and GAAP/IFRS standards.

**Defense Answer:**
In commercial ERP systems (such as SAP, Oracle Financials, or Microsoft Dynamics), a customer is not merely a contact record; they represent a distinct **Accounts Receivable Sub-Ledger**.

**Two Major Advantages:**
1. **Financial Immutability**: Instead of modifying an editable `current_balance` column on `customer_profiles` (which can be vulnerable to tampering or manual update errors), a customer's true balance is derived directly from the immutable double-entry ledger:
   $$\text{Customer Balance} = \sum \text{Debits} - \sum \text{Credits}$$
2. **Unified Trial Balance**: The general ledger trial balance can automatically aggregate individual customer accounts under account head `1100` (Accounts Receivable Control Account) or query them individually, ensuring total accounting reconciliation across bank, revenue, inventory, and trade debtors.

---

### Q7: Explain the FIFO Debt Settlement algorithm in `sp_record_customer_payment`. How does the database cursor behave?
**Examiner's Angle:** Tests understanding of procedural SQL, cursor navigation, loop termination, and debt amortization.

**Defense Answer:**
In wholesale trade, when a client pays a lump sum (e.g., PKR 250,000), commercial convention dictates that payment clears their **oldest outstanding bills first (First-In, First-Out)**.

**Cursor Execution Workflow:**
1. Declare a cursor ordering candidate invoices chronologically:
   ```sql
   DECLARE cur_invoices CURSOR FOR
       SELECT invoice_id, net_payable, paid_amount
         FROM sales_invoices
        WHERE customer_id = p_customer_id
          AND invoice_status IN ('Unpaid', 'Partially_Paid')
        ORDER BY invoice_date ASC, invoice_id ASC
          FOR UPDATE;
   ```
2. Initialize `v_remaining_funds = p_amount`.
3. Fetch each invoice into local variables. Compute unpaid balance: `net_payable - paid_amount`.
4. If `v_remaining_funds >= unpaid_balance`, fully settle the invoice (`paid_amount = net_payable`, `invoice_status = 'Paid'`) and decrement remaining funds.
5. If `v_remaining_funds < unpaid_balance`, partially settle (`paid_amount = paid_amount + remaining_funds`, `invoice_status = 'Partially_Paid'`) and exhaust remaining funds to 0.
6. The loop terminates when either all unpaid invoices are cleared or remaining funds drop to zero.

---

### Q8: Why did we select MySQL InnoDB as the storage engine instead of MyISAM?
**Examiner's Angle:** Tests storage engine knowledge, transactional capabilities, and storage mechanics.

**Defense Answer:**
| Architectural Requirement | InnoDB Engine | MyISAM Engine |
|---|---|---|
| **ACID Transactions** | Supported (`START TRANSACTION`, `COMMIT`, `ROLLBACK`) | Not supported (Atomic table updates only) |
| **Foreign Key Constraints** | Fully enforced (`ON DELETE RESTRICT/CASCADE`) | Ignored syntactically (no relational integrity) |
| **Row-Level Locking** | Yes (`FOR UPDATE`, non-blocking concurrency) | Table-level lock only (entire table blocked on write) |
| **Crash Recovery** | Redo Log & Undo Log (Automated WAL recovery) | Table corruption requiring manual `REPAIR TABLE` |
| **Data Integrity Checks** | `CHECK` constraints supported in MySQL 8.0+ | Limited constraint enforcement |

For a financial ledger and inventory system where money and inventory are at stake, MyISAM's lack of transactions, table-level locking bottlenecks, and missing foreign keys make it unusable. InnoDB is the only acceptable engine.

---

### Q9: Explain how composite index `idx_invoices_cust_date_status` optimizes the aging query using B-Tree indexing rules.
**Examiner's Angle:** Assesses B-Tree indexing theory, index selectivity, prefix matching, and query optimization.

**Defense Answer:**
The composite index is declared as:
```sql
CREATE INDEX idx_invoices_cust_date_status 
    ON sales_invoices(customer_id, invoice_date, invoice_status);
```
**B-Tree Optimization Mechanics:**
1. **Leftmost Prefix Rule**: Filtering begins with equality on `customer_id = ?`, allowing the MySQL query planner to instantly locate the contiguous leaf page sub-tree for that customer without scanning millions of irrelevant invoices.
2. **Range Filtering on Second Key**: The aging query filters `invoice_date >= DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY)`. The B-Tree can perform an index range scan along ordered date keys directly within that customer's sub-tree.
3. **Index Condition Pushdown (ICP)**: `invoice_status IN ('Unpaid', 'Partially_Paid')` is evaluated directly in the storage engine layer, discarding settled or cancelled invoices before reading table rows into server memory.
4. Running `EXPLAIN ANALYZE` confirms that `type = range`, eliminating expensive Full Table Scans (`type = ALL`) and avoiding disk-based Temporary Tables (`Using filesort`).

---

### Q10: Why are financial ledgers designed as "Append-Only" and immutable rather than executing destructive `UPDATE` or `DELETE` statements on transactions?
**Examiner's Angle:** Explores auditing standards, forensic accounting, data integrity, and compliance.

**Defense Answer:**
In commercial double-entry accounting and financial compliance (SOX, GAAP, IFRS), **a financial ledger is an append-only historical audit record**.

**Consequences of Destructive Updates/Deletions:**
1. If an invoice or receipt row is modified with an `UPDATE` or deleted with a `DELETE`, the mathematical audit trail is severed. External auditors cannot verify when, why, or who altered historical financials.
2. Updating historical invoices distorts historical tax, balance sheets, and profit-and-loss reports that were already closed and filed.
3. It opens opportunities for internal fraud and theft (e.g., deleting receipt records after pocketing cash).

**How This Repository Adheres to Financial Immutability:**
- To correct a billing error or return merchandise, the system does not delete an invoice; it issues an **offsetting credit memo voucher** (`reference_type = 'SALES_RETURN'` or `'BAD_DEBT_WRITEOFF'`) that posts equal and opposite debit/credit entries to the General Ledger.
- `credit_audit_logs` maintains a permanent, non-rewritable footprint of every credit limit enforcement action.

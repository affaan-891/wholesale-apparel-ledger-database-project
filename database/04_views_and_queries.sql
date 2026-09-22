-- ============================================================================
-- Wholesale Apparel Multi-Tier Ledger & Udhaar Management System
-- Analytical Views & Complex Viva-Ready Queries (MySQL 8.0+)
-- File: 04_views_and_queries.sql
-- ============================================================================

USE wholesale_ledger_db;

-- ============================================================================
-- PART 1: ANALYTICAL FINANCIAL & INVENTORY VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- View 1: vw_customer_aging_schedule
-- Purpose:
--   Evaluates Accounts Receivable credit risk dynamically using DATEDIFF.
--   Partitions unsettled invoice debt (net_payable - paid_amount) into standard
--   commercial aging buckets (0-30, 31-60, 61-90, and >90 Days Default Risk).
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_customer_aging_schedule;
CREATE VIEW vw_customer_aging_schedule AS
SELECT 
    cp.customer_id,
    cp.business_name,
    cp.owner_name,
    cp.phone,
    cp.city,
    cp.credit_limit,
    cp.payment_terms_days,
    cp.status AS customer_status,
    COALESCE(SUM(si.net_payable - si.paid_amount), 0.00) AS total_outstanding_debt,
    ROUND(cp.credit_limit - COALESCE(SUM(si.net_payable - si.paid_amount), 0.00), 2) AS available_credit,
    -- Aging Bucket 1: Current Debt (0 - 30 Days)
    COALESCE(SUM(
        CASE 
            WHEN DATEDIFF(CURRENT_DATE, si.invoice_date) BETWEEN 0 AND 30 
            THEN (si.net_payable - si.paid_amount) 
            ELSE 0.00 
        END
    ), 0.00) AS aging_bucket_0_to_30_days,
    -- Aging Bucket 2: Overdue Debt (31 - 60 Days)
    COALESCE(SUM(
        CASE 
            WHEN DATEDIFF(CURRENT_DATE, si.invoice_date) BETWEEN 31 AND 60 
            THEN (si.net_payable - si.paid_amount) 
            ELSE 0.00 
        END
    ), 0.00) AS aging_bucket_31_to_60_days,
    -- Aging Bucket 3: Delinquent Debt (61 - 90 Days)
    COALESCE(SUM(
        CASE 
            WHEN DATEDIFF(CURRENT_DATE, si.invoice_date) BETWEEN 61 AND 90 
            THEN (si.net_payable - si.paid_amount) 
            ELSE 0.00 
        END
    ), 0.00) AS aging_bucket_61_to_90_days,
    -- Aging Bucket 4: High Default Risk (> 90 Days)
    COALESCE(SUM(
        CASE 
            WHEN DATEDIFF(CURRENT_DATE, si.invoice_date) > 90 
            THEN (si.net_payable - si.paid_amount) 
            ELSE 0.00 
        END
    ), 0.00) AS aging_bucket_over_90_days
FROM customer_profiles cp
LEFT JOIN sales_invoices si 
       ON cp.customer_id = si.customer_id 
      AND si.invoice_status IN ('Unpaid', 'Partially_Paid')
GROUP BY 
    cp.customer_id,
    cp.business_name,
    cp.owner_name,
    cp.phone,
    cp.city,
    cp.credit_limit,
    cp.payment_terms_days,
    cp.status;

-- ----------------------------------------------------------------------------
-- View 2: vw_batch_inventory_valuation
-- Purpose:
--   Calculates physical inventory position, unit manufacturing cost valuation,
--   potential wholesale realization value, and unrealized gross profit margins
--   across all apparel cuts, colors, sizes, and active production lots.
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS vw_batch_inventory_valuation;
CREATE VIEW vw_batch_inventory_valuation AS
SELECT 
    pa.article_code,
    pa.article_name,
    pa.fabric_type,
    av.sku,
    av.color,
    av.size,
    ib.batch_id,
    ib.lot_number,
    ib.received_date,
    ib.available_pieces,
    ib.manufacturing_cost AS unit_manufacturing_cost,
    pa.base_wholesale_price AS unit_wholesale_price,
    ROUND(ib.available_pieces * ib.manufacturing_cost, 2) AS total_inventory_cost_value,
    ROUND(ib.available_pieces * pa.base_wholesale_price, 2) AS potential_wholesale_realization,
    ROUND((ib.available_pieces * pa.base_wholesale_price) - (ib.available_pieces * ib.manufacturing_cost), 2) AS potential_gross_profit,
    CASE 
        WHEN ib.available_pieces = 0 THEN 'OUT_OF_STOCK'
        WHEN ib.available_pieces < 50 THEN 'CRITICAL_LOW'
        WHEN ib.available_pieces < 150 THEN 'HEALTHY'
        ELSE 'SURPLUS'
    END AS stock_health_status
FROM product_articles pa
INNER JOIN article_variants av ON pa.article_id = av.article_id
INNER JOIN inventory_batches ib ON av.variant_id = ib.variant_id;


-- ============================================================================
-- PART 2: 5 COMPLEX VIVA-READY QUERIES WITH ACADEMIC JUSTIFICATION
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 1: High-Risk Delinquent Debtors (Overdue > 60 Days with Zero Payments)
-- DBMS Concepts Demonstrated:
--   - Multi-table INNER JOIN and LEFT JOIN aggregation
--   - Filtering on aggregated metrics via HAVING clause
--   - Temporal arithmetic using DATEDIFF and subquery payment correlation
-- ----------------------------------------------------------------------------
SELECT 
    cp.customer_id,
    cp.business_name,
    cp.owner_name,
    cp.phone,
    cp.city,
    cp.credit_limit,
    COUNT(DISTINCT si.invoice_id) AS delinquent_invoice_count,
    SUM(si.net_payable - si.paid_amount) AS total_overdue_debt
FROM customer_profiles cp
INNER JOIN sales_invoices si 
        ON cp.customer_id = si.customer_id
WHERE si.invoice_status IN ('Unpaid', 'Partially_Paid')
  AND DATEDIFF(CURRENT_DATE, si.invoice_date) > 60
  -- Correlated filter: Buyer has made zero payments in the last 30 calendar days
  AND NOT EXISTS (
      SELECT 1 
      FROM customer_receipts cr
      WHERE cr.customer_id = cp.customer_id
        AND DATEDIFF(CURRENT_DATE, cr.payment_date) <= 30
  )
GROUP BY 
    cp.customer_id,
    cp.business_name,
    cp.owner_name,
    cp.phone,
    cp.city,
    cp.credit_limit
HAVING total_overdue_debt > 50000.00
ORDER BY total_overdue_debt DESC;

-- ----------------------------------------------------------------------------
-- Query 2: Complete Stockout Anti-Join (Articles with Zero Inventory)
-- DBMS Concepts Demonstrated:
--   - Correlated NOT EXISTS anti-join optimization
--   - Avoidance of NULL pitfalls typical of `NOT IN (SELECT ...)`
--   - Multi-tier relationship traversal: Article -> Variant -> Batch
-- ----------------------------------------------------------------------------
SELECT 
    pa.article_id,
    pa.article_code,
    pa.article_name,
    pa.fabric_type,
    pa.base_wholesale_price
FROM product_articles pa
WHERE NOT EXISTS (
    SELECT 1 
    FROM article_variants av
    INNER JOIN inventory_batches ib ON av.variant_id = ib.variant_id
    WHERE av.article_id = pa.article_id
      AND ib.available_pieces > 0
)
ORDER BY pa.article_code ASC;

-- ----------------------------------------------------------------------------
-- Query 3: Correlated Subquery: Outlier High-Discount Invoices
-- DBMS Concepts Demonstrated:
--   - Correlated subqueries comparing an individual row to its geographic cohort
--   - Dynamic computation of discount percentage
--   - Auditing commercial compliance and salesperson margin leakage
-- ----------------------------------------------------------------------------
SELECT 
    si.invoice_id,
    si.invoice_number,
    cp.business_name,
    cp.city,
    si.gross_amount,
    si.special_discount,
    ROUND((si.special_discount / si.gross_amount) * 100, 2) AS invoice_discount_pct,
    (
        SELECT ROUND(AVG((si_inner.special_discount / si_inner.gross_amount) * 100), 2)
        FROM sales_invoices si_inner
        INNER JOIN customer_profiles cp_inner ON si_inner.customer_id = cp_inner.customer_id
        WHERE cp_inner.city = cp.city
          AND si_inner.gross_amount > 0
    ) AS city_average_discount_pct
FROM sales_invoices si
INNER JOIN customer_profiles cp ON si.customer_id = cp.customer_id
WHERE si.gross_amount > 0
  AND (si.special_discount / si.gross_amount) * 100 > (
      SELECT AVG((si_inner.special_discount / si_inner.gross_amount) * 100)
      FROM sales_invoices si_inner
      INNER JOIN customer_profiles cp_inner ON si_inner.customer_id = cp_inner.customer_id
      WHERE cp_inner.city = cp.city
        AND si_inner.gross_amount > 0
  )
ORDER BY invoice_discount_pct DESC;

-- ----------------------------------------------------------------------------
-- Query 4: Window Function: Ranking Wholesale Buyers by City Revenue
-- DBMS Concepts Demonstrated:
--   - Analytic Window Functions (DENSE_RANK() OVER (PARTITION BY ... ORDER BY ...))
--   - Multi-level aggregation without destructive subquery joins
--   - Real-world commercial ranking of wholesale client portfolios
-- ----------------------------------------------------------------------------
WITH CustomerRevenueCTE AS (
    SELECT 
        cp.customer_id,
        cp.business_name,
        cp.city,
        COALESCE(SUM(si.net_payable), 0.00) AS total_revenue_contribution,
        COUNT(si.invoice_id) AS total_orders_placed
    FROM customer_profiles cp
    LEFT JOIN sales_invoices si ON cp.customer_id = si.customer_id AND si.invoice_status <> 'Cancelled'
    GROUP BY cp.customer_id, cp.business_name, cp.city
)
SELECT 
    city,
    business_name,
    total_orders_placed,
    total_revenue_contribution,
    DENSE_RANK() OVER (
        PARTITION BY city 
        ORDER BY total_revenue_contribution DESC
    ) AS city_revenue_rank,
    DENSE_RANK() OVER (
        ORDER BY total_revenue_contribution DESC
    ) AS national_revenue_rank
FROM CustomerRevenueCTE
ORDER BY city ASC, city_revenue_rank ASC;

-- ----------------------------------------------------------------------------
-- Query 5: Execution Plan & Index Traversal Analysis (EXPLAIN ANALYZE)
-- DBMS Concepts Demonstrated:
--   - MySQL 8.0+ EXPLAIN ANALYZE evaluating actual vs estimated row counts
--   - Verification of Composite B-Tree Index: idx_invoices_cust_date_status
--   - Range scan vs Full Table Scan cost assessment
-- ----------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT 
    si.invoice_id,
    si.invoice_number,
    si.invoice_date,
    si.net_payable,
    si.paid_amount,
    (si.net_payable - si.paid_amount) AS remaining_debt
FROM sales_invoices si
WHERE si.customer_id = 1
  AND si.invoice_date >= DATE_SUB(CURRENT_DATE, INTERVAL 90 DAY)
  AND si.invoice_status IN ('Unpaid', 'Partially_Paid');

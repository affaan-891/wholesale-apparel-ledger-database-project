-- ============================================================================
-- Wholesale Apparel Multi-Tier Ledger & Udhaar Management System
-- Comprehensive Commercial Seed Data (MySQL 8.0+)
-- File: 05_seed_data.sql
-- ============================================================================

USE wholesale_ledger_db;

-- Disable Foreign Key checks temporarily during seed initialization
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE credit_audit_logs;
TRUNCATE TABLE customer_receipts;
TRUNCATE TABLE journal_ledger_entries;
TRUNCATE TABLE general_journal_vouchers;
TRUNCATE TABLE sales_invoice_items;
TRUNCATE TABLE sales_invoices;
TRUNCATE TABLE inventory_batches;
TRUNCATE TABLE article_variants;
TRUNCATE TABLE product_articles;
TRUNCATE TABLE customer_profiles;
TRUNCATE TABLE chart_of_accounts;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- 1. CHART OF ACCOUNTS (Control Accounts & Customer Sub-Ledgers)
-- ============================================================================
INSERT INTO chart_of_accounts (account_id, account_code, account_name, account_type, is_active) VALUES
-- General Ledger Control Accounts
(1,  '1010', 'Cash in Hand Vault',                      'Asset',     TRUE),
(2,  '1020', 'Meezan Bank - Commercial Operations',    'Asset',     TRUE),
(3,  '1100', 'Accounts Receivable Control Account',    'Asset',     TRUE),
(4,  '1200', 'Merchandise Finished Goods Inventory',   'Asset',     TRUE),
(5,  '2010', 'Accounts Payable - Mill & Dyeing Units', 'Liability', TRUE),
(6,  '3010', 'Wholesale Capital & Retained Earnings',  'Equity',    TRUE),
(7,  '4010', 'Wholesale Apparel Sales Revenue',        'Revenue',   TRUE),
(8,  '4020', 'Wholesale Sales Discounts Allowed',      'Expense',   TRUE),
(9,  '5010', 'Cost of Goods Sold - Apparel Batches',   'Expense',   TRUE),
(10, '5020', 'Bad Debt & Credit Loss Allowance',       'Expense',   TRUE),

-- Dedicated Wholesale Customer Sub-Ledger Accounts
(11, '1101', 'AR - Al-Rahim Cloth Emporium',           'Asset',     TRUE),
(12, '1102', 'AR - Madina Fabrics Wholesale',          'Asset',     TRUE),
(13, '1103', 'AR - Karachi Denim House',               'Asset',     TRUE),
(14, '1104', 'AR - Faisalabad Yarn & Stitch',          'Asset',     TRUE),
(15, '1105', 'AR - Gujranwala Garment Traders',        'Asset',     TRUE),
(16, '1106', 'AR - Rawalpindi Outfitters Ltd',         'Asset',     TRUE),
(17, '1107', 'AR - Sialkot Sports & Casuals',          'Asset',     TRUE),
(18, '1108', 'AR - Peshawar Frontier Textiles',        'Asset',     TRUE);

-- ============================================================================
-- 2. CUSTOMER PROFILES (Wholesale Buyers Across Major Commercial Hubs)
-- ============================================================================
INSERT INTO customer_profiles (customer_id, business_name, owner_name, phone, city, credit_limit, payment_terms_days, account_id, status) VALUES
(1, 'Al-Rahim Cloth Emporium',       'Haji Muhammad Rahim',  '+92-300-1112233', 'Lahore',      1500000.00, 30, 11, 'Active'),
(2, 'Madina Fabrics Wholesale',      'Sheikh Tariq Mehmood', '+92-301-4445566', 'Faisalabad',  1200000.00, 45, 12, 'Active'),
(3, 'Karachi Denim House',           'Khurram Shahzad',      '+92-321-7778899', 'Karachi',     2000000.00, 30, 13, 'Active'),
(4, 'Faisalabad Yarn & Stitch',      'Mian Zafar Iqbal',     '+92-333-2223344', 'Faisalabad',   800000.00, 15, 14, 'Active'),
(5, 'Gujranwala Garment Traders',    'Chaudhry Akram',       '+92-345-6667788', 'Gujranwala',   900000.00, 30, 15, 'Active'),
(6, 'Rawalpindi Outfitters Ltd',     'Malik Bilal Raza',     '+92-312-9990011', 'Rawalpindi',  1000000.00, 60, 16, 'Active'),
(7, 'Sialkot Sports & Casuals',      'Usman Ghani Butt',     '+92-302-3334455', 'Sialkot',      600000.00, 30, 17, 'Blocked'),
(8, 'Peshawar Frontier Textiles',    'Khan Sher Afghan',     '+92-315-8889900', 'Peshawar',     500000.00, 15, 18, 'Blacklisted');

-- ============================================================================
-- 3. PRODUCT ARTICLES (Master Apparel Catalog)
-- ============================================================================
INSERT INTO product_articles (article_id, article_code, article_name, fabric_type, base_wholesale_price) VALUES
(1, 'ART-DNM-001', 'Raw Selvedge Denim Jeans (Slim Fit)',   '14oz Rigid Cotton Denim',   1850.00),
(2, 'ART-SHR-002', 'Classic Oxford Button-Down Shirt',       '100% Combed Cotton 60s',    1250.00),
(3, 'ART-HOD-003', 'Winter Heavyweight Fleece Hoodie',       '380 GSM Brushed Cotton',    2400.00),
(4, 'ART-CHN-004', 'Stretch Cotton Casual Chino Trouser',    'Cotton Twill with 3% Lycra', 1450.00),
(5, 'ART-KRT-005', 'Royal Festive Embroidered Kurta',        'Pure Irish Linen',          2100.00),
(6, 'ART-POL-006', 'Athletic Pique Knit Polo Shirt',         'Double Lacoste Cotton',      950.00);

-- ============================================================================
-- 4. ARTICLE VARIANTS (Color & Size Matrix with Unique SKUs)
-- ============================================================================
INSERT INTO article_variants (variant_id, article_id, color, size, sku) VALUES
-- Article 1: Selvedge Denim
(1,  1, 'Indigo Blue', 'M',  'DNM-IB-M'),
(2,  1, 'Indigo Blue', 'L',  'DNM-IB-L'),
(3,  1, 'Midnight Black', 'L', 'DNM-MB-L'),
(4,  1, 'Midnight Black', 'XL','DNM-MB-XL'),

-- Article 2: Oxford Shirt
(5,  2, 'Crisp White', 'M',  'SHR-CW-M'),
(6,  2, 'Crisp White', 'L',  'SHR-CW-L'),
(7,  2, 'Sky Blue',    'L',  'SHR-SB-L'),
(8,  2, 'Sky Blue',    'XL', 'SHR-SB-XL'),

-- Article 3: Fleece Hoodie
(9,  3, 'Charcoal Heather', 'L',  'HOD-CH-L'),
(10, 3, 'Charcoal Heather', 'XL', 'HOD-CH-XL'),
(11, 3, 'Olive Green',      'L',  'HOD-OG-L'),

-- Article 4: Stretch Chino
(12, 4, 'Khaki Tan',   'M',  'CHN-KT-M'),
(13, 4, 'Khaki Tan',   'L',  'CHN-KT-L'),
(14, 4, 'Navy Blue',   'L',  'CHN-NB-L'),

-- Article 5: Irish Linen Kurta
(15, 5, 'Ivory Cream', 'M',  'KRT-IC-M'),
(16, 5, 'Ivory Cream', 'L',  'KRT-IC-L'),
(17, 5, 'Jet Black',   'XL', 'KRT-JB-XL'),

-- Article 6: Pique Polo (Zero stock test article for Viva Query 2)
(18, 6, 'Royal Maroon', 'M', 'POL-RM-M'),
(19, 6, 'Royal Maroon', 'L', 'POL-RM-L');

-- ============================================================================
-- 5. INVENTORY BATCHES (Production Lots & Cost Accounting)
-- Note: Initial available_pieces accounts for upcoming invoice consumption.
-- ============================================================================
INSERT INTO inventory_batches (batch_id, variant_id, lot_number, manufacturing_cost, available_pieces, received_date) VALUES
(1,  1,  'LOT-2026-DNM-01', 1150.00, 600, '2026-06-10'),
(2,  2,  'LOT-2026-DNM-02', 1150.00, 500, '2026-06-12'),
(3,  3,  'LOT-2026-DNM-03', 1180.00, 450, '2026-06-15'),
(4,  4,  'LOT-2026-DNM-04', 1180.00, 300, '2026-06-18'),
(5,  5,  'LOT-2026-SHR-01',  750.00, 800, '2026-06-20'),
(6,  6,  'LOT-2026-SHR-02',  750.00, 750, '2026-06-22'),
(7,  7,  'LOT-2026-SHR-03',  780.00, 600, '2026-06-25'),
(8,  8,  'LOT-2026-SHR-04',  780.00, 500, '2026-06-28'),
(9,  9,  'LOT-2026-HOD-01', 1450.00, 400, '2026-07-02'),
(10, 10, 'LOT-2026-HOD-02', 1450.00, 350, '2026-07-05'),
(11, 11, 'LOT-2026-HOD-03', 1480.00, 250, '2026-07-08'),
(12, 12, 'LOT-2026-CHN-01',  880.00, 550, '2026-07-10'),
(13, 13, 'LOT-2026-CHN-02',  880.00, 450, '2026-07-12'),
(14, 14, 'LOT-2026-CHN-03',  900.00, 400, '2026-07-15'),
(15, 15, 'LOT-2026-KRT-01', 1280.00, 300, '2026-07-18'),
(16, 16, 'LOT-2026-KRT-02', 1280.00, 250, '2026-07-20'),
(17, 17, 'LOT-2026-KRT-03', 1300.00, 150, '2026-07-22'),
(18, 1,  'LOT-2026-DNM-05', 1160.00, 200, '2026-08-01'),
(19, 5,  'LOT-2026-SHR-05',  760.00, 300, '2026-08-05'),
(20, 9,  'LOT-2026-HOD-04', 1460.00, 200, '2026-08-10'),
-- Batch 21 & 22 for Article 6 have 0 pieces to test stockout anti-join queries
(21, 18, 'LOT-2026-POL-01',  580.00,   0, '2026-05-01'),
(22, 19, 'LOT-2026-POL-02',  580.00,   0, '2026-05-05');

-- ============================================================================
-- 6. SALES INVOICES (Wholesale Credit Billing with Historical Aging Dates)
-- ============================================================================
INSERT INTO sales_invoices (invoice_id, invoice_number, customer_id, invoice_date, gross_amount, special_discount, net_payable, paid_amount, invoice_status) VALUES
-- Old Delinquent Invoices (>90 Days)
(1,  'INV-2026-001', 1, '2026-05-10', 185000.00,  5000.00, 180000.00, 180000.00, 'Paid'),
(2,  'INV-2026-002', 2, '2026-05-15', 240000.00, 10000.00, 230000.00, 100000.00, 'Partially_Paid'),
(3,  'INV-2026-003', 3, '2026-05-20', 370000.00, 15000.00, 355000.00, 355000.00, 'Paid'),

-- Aging Invoices (61 - 90 Days)
(4,  'INV-2026-004', 4, '2026-06-25', 125000.00,  2500.00, 122500.00,  50000.00, 'Partially_Paid'),
(5,  'INV-2026-005', 5, '2026-07-02', 290000.00,  8000.00, 282000.00,      0.00, 'Unpaid'),
(6,  'INV-2026-006', 6, '2026-07-10', 480000.00, 20000.00, 460000.00, 200000.00, 'Partially_Paid'),

-- Aging Invoices (31 - 60 Days)
(7,  'INV-2026-007', 1, '2026-07-25', 222000.00,  6000.00, 216000.00, 100000.00, 'Partially_Paid'),
(8,  'INV-2026-008', 2, '2026-08-05', 315000.00,  9000.00, 306000.00,      0.00, 'Unpaid'),
(9,  'INV-2026-009', 3, '2026-08-12', 425000.00, 12000.00, 413000.00, 250000.00, 'Partially_Paid'),

-- Current Invoices (0 - 30 Days)
(10, 'INV-2026-010', 4, '2026-08-28', 145000.00,  3000.00, 142000.00,      0.00, 'Unpaid'),
(11, 'INV-2026-011', 5, '2026-09-05', 185000.00,  4500.00, 180500.00,      0.00, 'Unpaid'),
(12, 'INV-2026-012', 6, '2026-09-15', 360000.00, 10000.00, 350000.00,      0.00, 'Unpaid');

-- ============================================================================
-- 7. SALES INVOICE ITEMS (Batch Stock Consumption)
-- Note: Insertion triggers trg_deduct_wholesale_batch_stock on available_pieces.
-- ============================================================================
INSERT INTO sales_invoice_items (item_id, invoice_id, batch_id, quantity_pieces, unit_wholesale_price, line_total) VALUES
-- Invoice 1 (185,000 gross)
(1,  1,  1,  100, 1850.00, 185000.00),

-- Invoice 2 (240,000 gross)
(2,  2,  9,  100, 2400.00, 240000.00),

-- Invoice 3 (370,000 gross)
(3,  3,  2,  100, 1850.00, 185000.00),
(4,  3,  3,  100, 1850.00, 185000.00),

-- Invoice 4 (125,000 gross)
(5,  4,  5,  100, 1250.00, 125000.00),

-- Invoice 5 (290,000 gross)
(6,  5,  12, 100, 1450.00, 145000.00),
(7,  5,  13, 100, 1450.00, 145000.00),

-- Invoice 6 (480,000 gross)
(8,  6,  9,  100, 2400.00, 240000.00),
(9,  6,  10, 100, 2400.00, 240000.00),

-- Invoice 7 (222,000 gross)
(10, 7,  1,  120, 1850.00, 222000.00),

-- Invoice 8 (315,000 gross)
(11, 8,  15, 150, 2100.00, 315000.00),

-- Invoice 9 (425,000 gross)
(12, 9,  2,  100, 1850.00, 185000.00),
(13, 9,  10, 100, 2400.00, 240000.00),

-- Invoice 10 (145,000 gross)
(14, 10, 14, 100, 1450.00, 145000.00),

-- Invoice 11 (185,000 gross)
(15, 11, 4,  100, 1850.00, 185000.00),

-- Invoice 12 (360,000 gross)
(16, 12, 11, 150, 2400.00, 360000.00);

-- ============================================================================
-- 8. GENERAL JOURNAL VOUCHERS & DOUBLE-ENTRY LEDGER ENTRIES
-- Balanced Journal Vouchers for all 12 Sales Invoices
-- Debits = Credits strictly enforced.
-- ============================================================================
-- Invoice 1 Voucher (AR: 180,000 + Disc: 5,000 = Rev: 185,000; COGS: 115,000 = Inv: 115,000)
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (1, 'JV-INV-000001', '2026-05-10', 'SALES_INVOICE', 1, 'Billing for wholesale invoice INV-2026-001');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(1, 11, 180000.00, 0.00),      -- AR - Al-Rahim
(1, 8,    5000.00, 0.00),      -- Sales Discount Allowed
(1, 7,       0.00, 185000.00),  -- Sales Revenue
(1, 9,  115000.00, 0.00),      -- COGS (100 * 1150)
(1, 4,       0.00, 115000.00);  -- Inventory

-- Invoice 2 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (2, 'JV-INV-000002', '2026-05-15', 'SALES_INVOICE', 2, 'Billing for wholesale invoice INV-2026-002');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(2, 12, 230000.00, 0.00),      -- AR - Madina Fabrics
(2, 8,   10000.00, 0.00),      -- Sales Discount Allowed
(2, 7,       0.00, 240000.00),  -- Sales Revenue
(2, 9,  145000.00, 0.00),      -- COGS (100 * 1450)
(2, 4,       0.00, 145000.00);  -- Inventory

-- Invoice 3 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (3, 'JV-INV-000003', '2026-05-20', 'SALES_INVOICE', 3, 'Billing for wholesale invoice INV-2026-003');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(3, 13, 355000.00, 0.00),      -- AR - Karachi Denim House
(3, 8,   15000.00, 0.00),      -- Sales Discount Allowed
(3, 7,       0.00, 370000.00),  -- Sales Revenue
(3, 9,  233000.00, 0.00),      -- COGS ((100*1150) + (100*1180))
(3, 4,       0.00, 233000.00);  -- Inventory

-- Invoice 4 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (4, 'JV-INV-000004', '2026-06-25', 'SALES_INVOICE', 4, 'Billing for wholesale invoice INV-2026-004');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(4, 14, 122500.00, 0.00),      -- AR - Faisalabad Yarn & Stitch
(4, 8,    2500.00, 0.00),      -- Sales Discount Allowed
(4, 7,       0.00, 125000.00),  -- Sales Revenue
(4, 9,   75000.00, 0.00),      -- COGS (100 * 750)
(4, 4,       0.00,  75000.00);  -- Inventory

-- Invoice 5 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (5, 'JV-INV-000005', '2026-07-02', 'SALES_INVOICE', 5, 'Billing for wholesale invoice INV-2026-005');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(5, 15, 282000.00, 0.00),      -- AR - Gujranwala Garments
(5, 8,    8000.00, 0.00),      -- Sales Discount
(5, 7,       0.00, 290000.00),  -- Sales Revenue
(5, 9,  176000.00, 0.00),      -- COGS (200 * 880)
(5, 4,       0.00, 176000.00);  -- Inventory

-- Invoice 6 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (6, 'JV-INV-000006', '2026-07-10', 'SALES_INVOICE', 6, 'Billing for wholesale invoice INV-2026-006');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(6, 16, 460000.00, 0.00),      -- AR - Rawalpindi Outfitters
(6, 8,   20000.00, 0.00),      -- Sales Discount
(6, 7,       0.00, 480000.00),  -- Sales Revenue
(6, 9,  290000.00, 0.00),      -- COGS (200 * 1450)
(6, 4,       0.00, 290000.00);  -- Inventory

-- Invoice 7 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (7, 'JV-INV-000007', '2026-07-25', 'SALES_INVOICE', 7, 'Billing for wholesale invoice INV-2026-007');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(7, 11, 216000.00, 0.00),      -- AR - Al-Rahim
(7, 8,    6000.00, 0.00),
(7, 7,       0.00, 222000.00),
(7, 9,  138000.00, 0.00),      -- COGS (120 * 1150)
(7, 4,       0.00, 138000.00);

-- Invoice 8 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (8, 'JV-INV-000008', '2026-08-05', 'SALES_INVOICE', 8, 'Billing for wholesale invoice INV-2026-008');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(8, 12, 306000.00, 0.00),      -- AR - Madina Fabrics
(8, 8,    9000.00, 0.00),
(8, 7,       0.00, 315000.00),
(8, 9,  192000.00, 0.00),      -- COGS (150 * 1280)
(8, 4,       0.00, 192000.00);

-- Invoice 9 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (9, 'JV-INV-000009', '2026-08-12', 'SALES_INVOICE', 9, 'Billing for wholesale invoice INV-2026-009');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(9, 13, 413000.00, 0.00),      -- AR - Karachi Denim House
(9, 8,   12000.00, 0.00),
(9, 7,       0.00, 425000.00),
(9, 9,  260000.00, 0.00),      -- COGS ((100*1150) + (100*1450))
(9, 4,       0.00, 260000.00);

-- Invoice 10 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (10, 'JV-INV-000010', '2026-08-28', 'SALES_INVOICE', 10, 'Billing for wholesale invoice INV-2026-010');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(10, 14, 142000.00, 0.00),     -- AR - Faisalabad Yarn & Stitch
(10, 8,    3000.00, 0.00),
(10, 7,       0.00, 145000.00),
(10, 9,   90000.00, 0.00),     -- COGS (100 * 900)
(10, 4,       0.00,  90000.00);

-- Invoice 11 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (11, 'JV-INV-000011', '2026-09-05', 'SALES_INVOICE', 11, 'Billing for wholesale invoice INV-2026-011');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(11, 15, 180500.00, 0.00),     -- AR - Gujranwala Garments
(11, 8,    4500.00, 0.00),
(11, 7,       0.00, 185000.00),
(11, 9,  118000.00, 0.00),     -- COGS (100 * 1180)
(11, 4,       0.00, 118000.00);

-- Invoice 12 Voucher
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (12, 'JV-INV-000012', '2026-09-15', 'SALES_INVOICE', 12, 'Billing for wholesale invoice INV-2026-012');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(12, 16, 350000.00, 0.00),     -- AR - Rawalpindi Outfitters
(12, 8,   10000.00, 0.00),
(12, 7,       0.00, 360000.00),
(12, 9,  222000.00, 0.00),     -- COGS (150 * 1480)
(12, 4,       0.00, 222000.00);


-- ============================================================================
-- 9. CUSTOMER RECEIPTS & SETTLEMENT GENERAL JOURNAL VOUCHERS
-- 8 Payments received from buyers settling udhaar balances.
-- Double Entry: Debit Bank/Cash, Credit Customer Sub-Ledger.
-- ============================================================================
INSERT INTO customer_receipts (receipt_id, receipt_number, customer_id, payment_date, amount_received, payment_mode, cheque_clearance_date, reference_note) VALUES
(1, 'RCT-2026-001', 1, '2026-06-01', 180000.00, 'Online_Transfer', '2026-06-01', 'Settlement for INV-2026-001 via Meezan Internet Banking'),
(2, 'RCT-2026-002', 2, '2026-06-15', 100000.00, 'Cheque',          '2026-06-18', 'HBL Cheque #449012 partial payment on INV-2026-002'),
(3, 'RCT-2026-003', 3, '2026-06-20', 355000.00, 'Online_Transfer', '2026-06-20', 'Full clearance of INV-2026-003 via Raast IMPS'),
(4, 'RCT-2026-004', 4, '2026-07-15',  50000.00, 'Cash',             NULL,         'Counter Cash deposit at wholesale facility'),
(5, 'RCT-2026-005', 6, '2026-08-01', 200000.00, 'Cheque',          '2026-08-04', 'MCB Cheque #881200 partial payment on INV-2026-006'),
(6, 'RCT-2026-006', 1, '2026-08-20', 100000.00, 'Online_Transfer', '2026-08-20', 'Partial settlement of INV-2026-007'),
(7, 'RCT-2026-007', 3, '2026-09-02', 250000.00, 'Online_Transfer', '2026-09-02', 'Interim transfer against denim consignment'),
(8, 'RCT-2026-008', 2, '2026-07-10',  50000.00, 'Cash',             NULL,         'Wholesale market cash recovery');

-- Receipts Double-Entry Ledger Vouchers
-- Receipt 1
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (13, 'JV-RCT-000001', '2026-06-01', 'CUSTOMER_PAYMENT', 1, 'Udhaar settlement receipt RCT-2026-001 from Al-Rahim Cloth Emporium');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(13, 2,  180000.00,      0.00),  -- Debit Meezan Bank
(13, 11,      0.00, 180000.00);  -- Credit AR - Al-Rahim

-- Receipt 2
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (14, 'JV-RCT-000002', '2026-06-15', 'CUSTOMER_PAYMENT', 2, 'Cheque payment RCT-2026-002 from Madina Fabrics Wholesale');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(14, 2,  100000.00,      0.00),  -- Debit Meezan Bank
(14, 12,      0.00, 100000.00);  -- Credit AR - Madina Fabrics

-- Receipt 3
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (15, 'JV-RCT-000003', '2026-06-20', 'CUSTOMER_PAYMENT', 3, 'Full payment RCT-2026-003 from Karachi Denim House');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(15, 2,  355000.00,      0.00),
(15, 13,      0.00, 355000.00);

-- Receipt 4
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (16, 'JV-RCT-000004', '2026-07-15', 'CUSTOMER_PAYMENT', 4, 'Cash receipt RCT-2026-004 from Faisalabad Yarn & Stitch');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(16, 1,   50000.00,      0.00),  -- Debit Cash in Hand
(16, 14,      0.00,  50000.00);  -- Credit AR - Faisalabad Yarn

-- Receipt 5
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (17, 'JV-RCT-000005', '2026-08-01', 'CUSTOMER_PAYMENT', 5, 'Cheque clearance RCT-2026-005 from Rawalpindi Outfitters');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(17, 2,  200000.00,      0.00),
(17, 16,      0.00, 200000.00);

-- Receipt 6
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (18, 'JV-RCT-000006', '2026-08-20', 'CUSTOMER_PAYMENT', 6, 'Interim transfer RCT-2026-006 from Al-Rahim Cloth Emporium');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(18, 2,  100000.00,      0.00),
(18, 11,      0.00, 100000.00);

-- Receipt 7
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (19, 'JV-RCT-000007', '2026-09-02', 'CUSTOMER_PAYMENT', 7, 'Transfer RCT-2026-007 from Karachi Denim House');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(19, 2,  250000.00,      0.00),
(19, 13,      0.00, 250000.00);

-- Receipt 8
INSERT INTO general_journal_vouchers (voucher_id, voucher_number, voucher_date, reference_type, reference_id, narration)
VALUES (20, 'JV-RCT-000008', '2026-07-10', 'CUSTOMER_PAYMENT', 8, 'Cash recovery RCT-2026-008 from Madina Fabrics Wholesale');
INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit) VALUES
(20, 1,   50000.00,      0.00),
(20, 12,      0.00,  50000.00);

-- ============================================================================
-- 10. CREDIT AUDIT LOGS (Compliance & Historical Limit Approvals)
-- ============================================================================
INSERT INTO credit_audit_logs (log_id, customer_id, previous_balance, new_balance, limit_threshold, action_taken, logged_at) VALUES
(1, 1,      0.00, 180000.00, 1500000.00, 'Invoice Authorized: INV-2026-001', '2026-05-10 10:15:00'),
(2, 2,      0.00, 230000.00, 1200000.00, 'Invoice Authorized: INV-2026-002', '2026-05-15 11:30:00'),
(3, 3,      0.00, 355000.00, 2000000.00, 'Invoice Authorized: INV-2026-003', '2026-05-20 14:00:00'),
(4, 4,      0.00, 122500.00,  800000.00, 'Invoice Authorized: INV-2026-004', '2026-06-25 09:45:00'),
(5, 5,      0.00, 282000.00,  900000.00, 'Invoice Authorized: INV-2026-005', '2026-07-02 16:20:00'),
(6, 6,      0.00, 460000.00, 1000000.00, 'Invoice Authorized: INV-2026-006', '2026-07-10 12:10:00'),
(7, 1,      0.00, 216000.00, 1500000.00, 'Invoice Authorized: INV-2026-007', '2026-07-25 15:40:00'),
(8, 7, 580000.00, 680000.00,  600000.00, 'Credit Block Enforced: Status changed to Blocked', '2026-07-28 17:00:00'),
(9, 8, 490000.00, 520000.00,  500000.00, 'Default Warning: Account placed on Blacklist',    '2026-08-01 10:00:00');

-- ============================================================================
-- Wholesale Apparel Multi-Tier Ledger & Udhaar Management System
-- Database Schema DDL (3NF Normalized, InnoDB, MySQL 8.0+)
-- File: 01_schema.sql
-- ============================================================================

DROP DATABASE IF EXISTS wholesale_ledger_db;
CREATE DATABASE wholesale_ledger_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE wholesale_ledger_db;

-- ----------------------------------------------------------------------------
-- Table 1: chart_of_accounts
-- Master chart for the double-entry general ledger bookkeeping system.
-- Accommodates standard accounting heads and dedicated customer sub-ledgers.
-- ----------------------------------------------------------------------------
CREATE TABLE chart_of_accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    account_code VARCHAR(20) NOT NULL,
    account_name VARCHAR(100) NOT NULL,
    account_type ENUM('Asset', 'Liability', 'Equity', 'Revenue', 'Expense') NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_account_code UNIQUE (account_code)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 2: customer_profiles
-- Wholesale buyers with credit limits, authorized payment terms, and 1:1
-- linkage to their dedicated accounts receivable sub-ledger account.
-- ----------------------------------------------------------------------------
CREATE TABLE customer_profiles (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    business_name VARCHAR(150) NOT NULL,
    owner_name VARCHAR(100) NOT NULL,
    phone VARCHAR(25) NOT NULL,
    city VARCHAR(50) NOT NULL,
    credit_limit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    payment_terms_days INT NOT NULL DEFAULT 30,
    account_id INT NOT NULL,
    status ENUM('Active', 'Blocked', 'Blacklisted') NOT NULL DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_customer_phone UNIQUE (phone),
    CONSTRAINT uq_customer_account UNIQUE (account_id),
    CONSTRAINT chk_customer_credit_limit CHECK (credit_limit >= 0.00),
    CONSTRAINT chk_customer_payment_terms CHECK (payment_terms_days >= 0),
    CONSTRAINT fk_customer_account
        FOREIGN KEY (account_id) REFERENCES chart_of_accounts(account_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 3: product_articles
-- Master apparel articles representing distinct wholesale designs/cuts.
-- ----------------------------------------------------------------------------
CREATE TABLE product_articles (
    article_id INT AUTO_INCREMENT PRIMARY KEY,
    article_code VARCHAR(30) NOT NULL,
    article_name VARCHAR(100) NOT NULL,
    fabric_type VARCHAR(50) NOT NULL,
    base_wholesale_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_article_code UNIQUE (article_code),
    CONSTRAINT chk_base_wholesale_price CHECK (base_wholesale_price > 0.00)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 4: article_variants
-- Color and size matrices for articles with unique Stock Keeping Units (SKUs).
-- ----------------------------------------------------------------------------
CREATE TABLE article_variants (
    variant_id INT AUTO_INCREMENT PRIMARY KEY,
    article_id INT NOT NULL,
    color VARCHAR(30) NOT NULL,
    size ENUM('S', 'M', 'L', 'XL', 'XXL', 'FreeSize') NOT NULL,
    sku VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_variant_sku UNIQUE (sku),
    CONSTRAINT uq_article_color_size UNIQUE (article_id, color, size),
    CONSTRAINT fk_variant_article
        FOREIGN KEY (article_id) REFERENCES product_articles(article_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 5: inventory_batches
-- Physical inventory tracking at the production lot level. Maintains unit
-- manufacturing cost for accurate Cost of Goods Sold (COGS) accounting.
-- ----------------------------------------------------------------------------
CREATE TABLE inventory_batches (
    batch_id INT AUTO_INCREMENT PRIMARY KEY,
    variant_id INT NOT NULL,
    lot_number VARCHAR(50) NOT NULL,
    manufacturing_cost DECIMAL(10,2) NOT NULL,
    available_pieces INT NOT NULL DEFAULT 0,
    received_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_variant_lot UNIQUE (variant_id, lot_number),
    CONSTRAINT chk_manufacturing_cost CHECK (manufacturing_cost > 0.00),
    CONSTRAINT chk_available_pieces CHECK (available_pieces >= 0),
    CONSTRAINT fk_batch_variant
        FOREIGN KEY (variant_id) REFERENCES article_variants(variant_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 6: sales_invoices
-- Wholesale credit bill headers representing commercial transactions.
-- Tracks gross sales, commercial discounts, net receivable, and paid balances.
-- ----------------------------------------------------------------------------
CREATE TABLE sales_invoices (
    invoice_id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_number VARCHAR(30) NOT NULL,
    customer_id INT NOT NULL,
    invoice_date DATE NOT NULL,
    gross_amount DECIMAL(12,2) NOT NULL,
    special_discount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    net_payable DECIMAL(12,2) NOT NULL,
    paid_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    invoice_status ENUM('Unpaid', 'Partially_Paid', 'Paid', 'Cancelled') NOT NULL DEFAULT 'Unpaid',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_invoice_number UNIQUE (invoice_number),
    CONSTRAINT chk_invoice_gross CHECK (gross_amount >= 0.00),
    CONSTRAINT chk_invoice_discount CHECK (special_discount >= 0.00),
    CONSTRAINT chk_invoice_net CHECK (net_payable >= 0.00),
    CONSTRAINT chk_invoice_paid CHECK (paid_amount >= 0.00),
    CONSTRAINT fk_invoice_customer
        FOREIGN KEY (customer_id) REFERENCES customer_profiles(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 7: sales_invoice_items
-- Granular invoice line items tied directly to specific inventory batches.
-- ----------------------------------------------------------------------------
CREATE TABLE sales_invoice_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_id INT NOT NULL,
    batch_id INT NOT NULL,
    quantity_pieces INT NOT NULL,
    unit_wholesale_price DECIMAL(10,2) NOT NULL,
    line_total DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_item_quantity CHECK (quantity_pieces > 0),
    CONSTRAINT chk_item_unit_price CHECK (unit_wholesale_price > 0.00),
    CONSTRAINT chk_item_line_total CHECK (line_total >= 0.00),
    CONSTRAINT fk_item_invoice
        FOREIGN KEY (invoice_id) REFERENCES sales_invoices(invoice_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_item_batch
        FOREIGN KEY (batch_id) REFERENCES inventory_batches(batch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 8: general_journal_vouchers
-- Immutable voucher headers representing distinct financial accounting events.
-- ----------------------------------------------------------------------------
CREATE TABLE general_journal_vouchers (
    voucher_id INT AUTO_INCREMENT PRIMARY KEY,
    voucher_number VARCHAR(30) NOT NULL,
    voucher_date DATE NOT NULL,
    reference_type ENUM('SALES_INVOICE', 'CUSTOMER_PAYMENT', 'SALES_RETURN', 'BAD_DEBT_WRITEOFF') NOT NULL,
    reference_id INT NOT NULL,
    narration TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_voucher_number UNIQUE (voucher_number)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 9: journal_ledger_entries
-- Double-entry transactional legs. Every voucher must balance (Debits = Credits).
-- Mutually exclusive constraint ensures a row is either a debit or a credit.
-- ----------------------------------------------------------------------------
CREATE TABLE journal_ledger_entries (
    entry_id INT AUTO_INCREMENT PRIMARY KEY,
    voucher_id INT NOT NULL,
    account_id INT NOT NULL,
    debit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    credit DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_ledger_debit_nonneg CHECK (debit >= 0.00),
    CONSTRAINT chk_ledger_credit_nonneg CHECK (credit >= 0.00),
    CONSTRAINT chk_ledger_mutually_exclusive CHECK (
        (debit > 0.00 AND credit = 0.00) OR 
        (debit = 0.00 AND credit > 0.00)
    ),
    CONSTRAINT fk_ledger_voucher
        FOREIGN KEY (voucher_id) REFERENCES general_journal_vouchers(voucher_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ledger_account
        FOREIGN KEY (account_id) REFERENCES chart_of_accounts(account_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 10: customer_receipts
-- Real-world money inflows (cash, cheques, online transfers) collected from
-- wholesale buyers to settle credit (udhaar) obligations.
-- ----------------------------------------------------------------------------
CREATE TABLE customer_receipts (
    receipt_id INT AUTO_INCREMENT PRIMARY KEY,
    receipt_number VARCHAR(30) NOT NULL,
    customer_id INT NOT NULL,
    payment_date DATE NOT NULL,
    amount_received DECIMAL(12,2) NOT NULL,
    payment_mode ENUM('Cash', 'Cheque', 'Online_Transfer') NOT NULL,
    cheque_clearance_date DATE NULL,
    reference_note VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_receipt_number UNIQUE (receipt_number),
    CONSTRAINT chk_receipt_amount CHECK (amount_received > 0.00),
    CONSTRAINT fk_receipt_customer
        FOREIGN KEY (customer_id) REFERENCES customer_profiles(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 11: credit_audit_logs
-- Immutable compliance and audit logging for customer credit limit tracking.
-- Records breaches, approvals, and dynamic ledger balance verifications.
-- ----------------------------------------------------------------------------
CREATE TABLE credit_audit_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    previous_balance DECIMAL(12,2) NOT NULL,
    new_balance DECIMAL(12,2) NOT NULL,
    limit_threshold DECIMAL(12,2) NOT NULL,
    action_taken VARCHAR(100) NOT NULL,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_audit_customer
        FOREIGN KEY (customer_id) REFERENCES customer_profiles(customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- PERFORMANCE & COMPLIANCE INDEXES
-- Optimizes B-tree index traversal for aging schedule queries and ledger lookups.
-- ============================================================================
CREATE INDEX idx_customer_city_status ON customer_profiles(city, status);
CREATE INDEX idx_variants_article ON article_variants(article_id);
CREATE INDEX idx_batches_variant_avail ON inventory_batches(variant_id, available_pieces);
CREATE INDEX idx_invoices_cust_date_status ON sales_invoices(customer_id, invoice_date, invoice_status);
CREATE INDEX idx_invoice_items_batch ON sales_invoice_items(batch_id);
CREATE INDEX idx_vouchers_ref ON general_journal_vouchers(reference_type, reference_id);
CREATE INDEX idx_ledger_account_voucher ON journal_ledger_entries(account_id, voucher_id);
CREATE INDEX idx_receipts_customer_date ON customer_receipts(customer_id, payment_date);
CREATE INDEX idx_audit_cust_logged ON credit_audit_logs(customer_id, logged_at);

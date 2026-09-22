-- ============================================================================
-- Wholesale Apparel Multi-Tier Ledger & Udhaar Management System
-- Stored Procedures & Functions (ACID Transactions, FIFO Settlement)
-- File: 03_procedures.sql
-- ============================================================================

USE wholesale_ledger_db;

DELIMITER //

-- ----------------------------------------------------------------------------
-- Function: fn_get_customer_current_debt
-- Returns the live net outstanding receivables for a given customer
-- based on their dedicated sub-ledger account in the General Ledger.
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_get_customer_current_debt //
CREATE FUNCTION fn_get_customer_current_debt(
    p_customer_id INT
)
RETURNS DECIMAL(12,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_account_id INT;
    DECLARE v_current_debt DECIMAL(12,2) DEFAULT 0.00;

    -- Retrieve the customer's linked sub-ledger account
    SELECT account_id
      INTO v_account_id
      FROM customer_profiles
     WHERE customer_id = p_customer_id;

    IF v_account_id IS NULL THEN
        RETURN 0.00;
    END IF;

    -- Calculate Net Debit Balance: SUM(debit) - SUM(credit)
    SELECT COALESCE(SUM(debit) - SUM(credit), 0.00)
      INTO v_current_debt
      FROM journal_ledger_entries
     WHERE account_id = v_account_id;

    RETURN v_current_debt;
END //

-- ----------------------------------------------------------------------------
-- Procedure: sp_post_sales_invoice_with_ledger
-- Description:
--   Executes atomic wholesale invoice generation under an explicit ACID
--   transaction boundary. Employs pessimistic row-level locking (FOR UPDATE)
--   on customer credit profiles and inventory batches to prevent race conditions.
--
-- Parameters:
--   p_customer_id: Wholesale buyer ID
--   p_items_json: JSON array of items: [{"batch_id": 1, "quantity": 10, "unit_price": 1250.00}]
--   p_discount: Special commercial deduction
--   OUT p_invoice_id: Generated invoice identifier
--   OUT p_net_payable: Final receivable balance
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_post_sales_invoice_with_ledger //
CREATE PROCEDURE sp_post_sales_invoice_with_ledger (
    IN  p_customer_id INT,
    IN  p_items_json  JSON,
    IN  p_discount    DECIMAL(10,2),
    OUT p_invoice_id  INT,
    OUT p_net_payable DECIMAL(12,2)
)
proc_label: BEGIN
    -- Error Handling & ACID Rollback declaration
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Local Variables
    DECLARE v_cust_account_id INT;
    DECLARE v_credit_limit    DECIMAL(12,2);
    DECLARE v_customer_status VARCHAR(20);
    DECLARE v_current_debt    DECIMAL(12,2);
    DECLARE v_gross_total     DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_total_cogs      DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_discount_amt    DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_invoice_number  VARCHAR(30);
    DECLARE v_voucher_id      INT;
    DECLARE v_voucher_number  VARCHAR(30);
    DECLARE v_item_count      INT;
    DECLARE i                 INT DEFAULT 0;

    -- Accounting Head IDs from Chart of Accounts
    DECLARE v_acc_sales_revenue   INT;
    DECLARE v_acc_sales_discount  INT;
    DECLARE v_acc_cogs            INT;
    DECLARE v_acc_inventory       INT;

    -- Step 1: Start ACID Transaction
    START TRANSACTION;

    -- Step 2: Pessimistic Row Locking on Customer Profile
    SELECT account_id, credit_limit, status
      INTO v_cust_account_id, v_credit_limit, v_customer_status
      FROM customer_profiles
     WHERE customer_id = p_customer_id
       FOR UPDATE;

    IF v_cust_account_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Validation Error: Customer profile does not exist.';
    END IF;

    IF v_customer_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Credit Restriction: Customer status is not Active.';
    END IF;

    -- Step 3: Fetch standard GL account IDs
    SELECT account_id INTO v_acc_sales_revenue  FROM chart_of_accounts WHERE account_code = '4010' LIMIT 1;
    SELECT account_id INTO v_acc_sales_discount FROM chart_of_accounts WHERE account_code = '4020' LIMIT 1;
    SELECT account_id INTO v_acc_cogs           FROM chart_of_accounts WHERE account_code = '5010' LIMIT 1;
    SELECT account_id INTO v_acc_inventory      FROM chart_of_accounts WHERE account_code = '1200' LIMIT 1;

    -- Step 4: Validate JSON item array
    SET v_item_count = JSON_LENGTH(p_items_json);
    IF v_item_count IS NULL OR v_item_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Validation Error: Invoice must contain at least one item line in JSON payload.';
    END IF;

    -- Step 5: Process and aggregate items, pessimistic locking on inventory batches
    SET i = 0;
    WHILE i < v_item_count DO
        SET @cur_batch_id   = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', i, '].batch_id'))) AS UNSIGNED);
        SET @cur_qty        = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', i, '].quantity'))) AS UNSIGNED);
        SET @cur_unit_price = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', i, '].unit_price'))) AS DECIMAL(10,2));

        -- Lock batch row
        SELECT available_pieces, manufacturing_cost
          INTO @cur_avail, @cur_mfg_cost
          FROM inventory_batches
         WHERE batch_id = @cur_batch_id
           FOR UPDATE;

        IF @cur_avail IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Validation Error: Inventory batch not found.';
        END IF;

        IF @cur_avail < @cur_qty THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Stock Out Error: Requested quantity exceeds batch available pieces.';
        END IF;

        SET v_gross_total = v_gross_total + (@cur_qty * @cur_unit_price);
        SET v_total_cogs  = v_total_cogs + (@cur_qty * @cur_mfg_cost);
        SET i = i + 1;
    END WHILE;

    -- Step 6: Determine Net Payable & Credit Check
    SET v_discount_amt = COALESCE(p_discount, 0.00);
    SET p_net_payable  = v_gross_total - v_discount_amt;

    IF p_net_payable < 0.00 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Commercial Error: Discount amount cannot exceed gross sales total.';
    END IF;

    SET v_current_debt = fn_get_customer_current_debt(p_customer_id);

    IF (v_current_debt + p_net_payable) > v_credit_limit THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Credit Limit Breach: Outstanding balance plus new invoice exceeds authorized credit ceiling.';
    END IF;

    -- Step 7: Generate Invoice Record
    SET v_invoice_number = CONCAT('INV-', DATE_FORMAT(CURRENT_DATE, '%Y%m%d'), '-', LPAD(FLOOR(RAND() * 89999 + 10000), 5, '0'));

    INSERT INTO sales_invoices (
        invoice_number,
        customer_id,
        invoice_date,
        gross_amount,
        special_discount,
        net_payable,
        paid_amount,
        invoice_status
    ) VALUES (
        v_invoice_number,
        p_customer_id,
        CURRENT_DATE,
        v_gross_total,
        v_discount_amt,
        p_net_payable,
        0.00,
        'Unpaid'
    );

    SET p_invoice_id = LAST_INSERT_ID();

    -- Step 8: Insert Invoice Line Items (Stock decrement trigger trg_deduct_wholesale_batch_stock fires automatically)
    SET i = 0;
    WHILE i < v_item_count DO
        SET @cur_batch_id   = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', i, '].batch_id'))) AS UNSIGNED);
        SET @cur_qty        = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', i, '].quantity'))) AS UNSIGNED);
        SET @cur_unit_price = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_items_json, CONCAT('$[', i, '].unit_price'))) AS DECIMAL(10,2));

        INSERT INTO sales_invoice_items (
            invoice_id,
            batch_id,
            quantity_pieces,
            unit_wholesale_price,
            line_total
        ) VALUES (
            p_invoice_id,
            @cur_batch_id,
            @cur_qty,
            @cur_unit_price,
            (@cur_qty * @cur_unit_price)
        );

        SET i = i + 1;
    END WHILE;

    -- Step 9: Post Immutable Double-Entry Journal Voucher
    SET v_voucher_number = CONCAT('JV-INV-', LPAD(p_invoice_id, 6, '0'));

    INSERT INTO general_journal_vouchers (
        voucher_number,
        voucher_date,
        reference_type,
        reference_id,
        narration
    ) VALUES (
        v_voucher_number,
        CURRENT_DATE,
        'SALES_INVOICE',
        p_invoice_id,
        CONCAT('Wholesale sales billing for invoice ', v_invoice_number, ' with batch inventory cost recognition.')
    );

    SET v_voucher_id = LAST_INSERT_ID();

    -- Double Entry Line 1: Debit Accounts Receivable (Customer Sub-ledger)
    INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit)
    VALUES (v_voucher_id, v_cust_account_id, p_net_payable, 0.00);

    -- Double Entry Line 2: Debit Sales Discount (if applicable)
    IF v_discount_amt > 0.00 THEN
        INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit)
        VALUES (v_voucher_id, v_acc_sales_discount, v_discount_amt, 0.00);
    END IF;

    -- Double Entry Line 3: Credit Wholesale Sales Revenue (Gross Amount)
    INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit)
    VALUES (v_voucher_id, v_acc_sales_revenue, 0.00, v_gross_total);

    -- Double Entry Line 4: Debit Cost of Goods Sold (COGS)
    INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit)
    VALUES (v_voucher_id, v_acc_cogs, v_total_cogs, 0.00);

    -- Double Entry Line 5: Credit Merchandise Finished Goods Inventory
    INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit)
    VALUES (v_voucher_id, v_acc_inventory, 0.00, v_total_cogs);

    -- Step 10: Validate Double-Entry Equilibrium
    CALL sp_verify_voucher_balance(v_voucher_id);

    -- Step 11: Commit Transaction
    COMMIT;
END //

-- ----------------------------------------------------------------------------
-- Procedure: sp_record_customer_payment
-- Description:
--   Processes customer payments (cash, cheques, online transfers) and applies
--   funds using a First-In, First-Out (FIFO) invoice settlement algorithm.
--   Posts atomic double-entry ledger entries:
--     Debit: Cash in Hand (1010) or Bank Account (1020)
--     Credit: Customer Sub-Ledger (Accounts Receivable)
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_record_customer_payment //
CREATE PROCEDURE sp_record_customer_payment (
    IN  p_customer_id       INT,
    IN  p_amount            DECIMAL(12,2),
    IN  p_payment_mode      ENUM('Cash', 'Cheque', 'Online_Transfer'),
    IN  p_reference_note    VARCHAR(255),
    IN  p_cheque_date       DATE,
    OUT p_receipt_id        INT,
    OUT p_unallocated_funds DECIMAL(12,2)
)
BEGIN
    -- Error Handling & ACID Rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Local Variables
    DECLARE v_cust_account_id   INT;
    DECLARE v_deposit_account_id INT;
    DECLARE v_receipt_number    VARCHAR(30);
    DECLARE v_voucher_id        INT;
    DECLARE v_voucher_number    VARCHAR(30);
    DECLARE v_remaining_funds   DECIMAL(12,2);
    DECLARE done                INT DEFAULT FALSE;

    -- Cursor variables for FIFO invoice iteration
    DECLARE cur_inv_id          INT;
    DECLARE cur_net_payable     DECIMAL(12,2);
    DECLARE cur_paid_amount     DECIMAL(12,2);
    DECLARE cur_unpaid_balance  DECIMAL(12,2);
    DECLARE v_apply_amount      DECIMAL(12,2);

    -- Cursor for FIFO Debt Aging Settlement
    DECLARE cur_invoices CURSOR FOR
        SELECT invoice_id, net_payable, paid_amount
          FROM sales_invoices
         WHERE customer_id = p_customer_id
           AND invoice_status IN ('Unpaid', 'Partially_Paid')
         ORDER BY invoice_date ASC, invoice_id ASC
           FOR UPDATE;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Input Validation
    IF p_amount <= 0.00 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Payment Error: Amount received must be strictly greater than zero.';
    END IF;

    -- Start ACID Transaction
    START TRANSACTION;

    -- Identify Customer Sub-Ledger Account
    SELECT account_id
      INTO v_cust_account_id
      FROM customer_profiles
     WHERE customer_id = p_customer_id
       FOR UPDATE;

    IF v_cust_account_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Validation Error: Customer profile not found.';
    END IF;

    -- Map Payment Mode to Asset Cash/Bank Account Head
    IF p_payment_mode = 'Cash' THEN
        SELECT account_id INTO v_deposit_account_id FROM chart_of_accounts WHERE account_code = '1010' LIMIT 1;
    ELSE
        SELECT account_id INTO v_deposit_account_id FROM chart_of_accounts WHERE account_code = '1020' LIMIT 1;
    END IF;

    -- Generate Customer Receipt
    SET v_receipt_number = CONCAT('RCT-', DATE_FORMAT(CURRENT_DATE, '%Y%m%d'), '-', LPAD(FLOOR(RAND() * 89999 + 10000), 5, '0'));

    INSERT INTO customer_receipts (
        receipt_number,
        customer_id,
        payment_date,
        amount_received,
        payment_mode,
        cheque_clearance_date,
        reference_note
    ) VALUES (
        v_receipt_number,
        p_customer_id,
        CURRENT_DATE,
        p_amount,
        p_payment_mode,
        p_cheque_date,
        p_reference_note
    );

    SET p_receipt_id = LAST_INSERT_ID();
    SET v_remaining_funds = p_amount;

    -- FIFO Allocation against oldest unpaid sales invoices
    OPEN cur_invoices;

    read_loop: LOOP
        FETCH cur_invoices INTO cur_inv_id, cur_net_payable, cur_paid_amount;
        IF done OR v_remaining_funds <= 0.00 THEN
            LEAVE read_loop;
        END IF;

        SET cur_unpaid_balance = cur_net_payable - cur_paid_amount;

        IF v_remaining_funds >= cur_unpaid_balance THEN
            -- Full settlement of this specific invoice
            SET v_apply_amount = cur_unpaid_balance;
            UPDATE sales_invoices
               SET paid_amount = paid_amount + v_apply_amount,
                   invoice_status = 'Paid'
             WHERE invoice_id = cur_inv_id;

            SET v_remaining_funds = v_remaining_funds - v_apply_amount;
        ELSE
            -- Partial settlement of this specific invoice
            SET v_apply_amount = v_remaining_funds;
            UPDATE sales_invoices
               SET paid_amount = paid_amount + v_apply_amount,
                   invoice_status = 'Partially_Paid'
             WHERE invoice_id = cur_inv_id;

            SET v_remaining_funds = 0.00;
        END IF;
    END LOOP;

    CLOSE cur_invoices;

    SET p_unallocated_funds = v_remaining_funds;

    -- Post General Journal Voucher for Payment Received
    SET v_voucher_number = CONCAT('JV-RCT-', LPAD(p_receipt_id, 6, '0'));

    INSERT INTO general_journal_vouchers (
        voucher_number,
        voucher_date,
        reference_type,
        reference_id,
        narration
    ) VALUES (
        v_voucher_number,
        CURRENT_DATE,
        'CUSTOMER_PAYMENT',
        p_receipt_id,
        CONCAT('Customer udhaar settlement receipt ', v_receipt_number, ' via ', p_payment_mode)
    );

    SET v_voucher_id = LAST_INSERT_ID();

    -- Double Entry: Debit Cash/Bank Asset Account
    INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit)
    VALUES (v_voucher_id, v_deposit_account_id, p_amount, 0.00);

    -- Double Entry: Credit Customer Accounts Receivable Sub-Ledger
    INSERT INTO journal_ledger_entries (voucher_id, account_id, debit, credit)
    VALUES (v_voucher_id, v_cust_account_id, 0.00, p_amount);

    -- Verify balanced entries
    CALL sp_verify_voucher_balance(v_voucher_id);

    -- Commit Transaction
    COMMIT;
END //

DELIMITER ;

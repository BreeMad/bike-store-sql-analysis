-- =====================================================
-- Bike Store Sales & Operations Analysis in MySQL
-- File: 02_data_cleaning.sql
-- Purpose: Validate data quality and transform raw data
-- =====================================================

USE bike_store_db;

-- =====================================================
-- CUSTOMER DATA VALIDATION
-- =====================================================

-- Check for missing values in customers table
SELECT *
FROM customers
WHERE first_name IS NULL
   OR last_name IS NULL
   OR phone IS NULL
   OR email IS NULL
   OR street IS NULL
   OR city IS NULL
   OR state IS NULL
   OR zip_code IS NULL;

-- Count missing phone numbers
SELECT COUNT(*) AS missing_phone_numbers
FROM customers
WHERE phone IS NULL;

-- Temporarily disable safe update mode for controlled update
SET SQL_SAFE_UPDATES = 0;

-- Replace missing phone numbers with placeholder
UPDATE customers
SET phone = 'No-Number'
WHERE phone IS NULL;

-- Re-enable safe update protection
SET SQL_SAFE_UPDATES = 1;

-- Verify update
SELECT COUNT(*) AS remaining_missing_phone_numbers
FROM customers
WHERE phone IS NULL;


-- =====================================================
-- ORDER DATA VALIDATION
-- =====================================================

-- Check for missing critical order fields
SELECT *
FROM orders
WHERE customer_id IS NULL
   OR order_status IS NULL
   OR order_date IS NULL
   OR store_id IS NULL
   OR staff_id IS NULL;


-- =====================================================
-- DATE FORMAT VALIDATION
-- =====================================================

-- Identify rows where dates cannot be converted
SELECT
    order_id,
    order_date,
    required_date,
    shipped_date
FROM orders
WHERE STR_TO_DATE(order_date, '%c/%e/%Y') IS NULL
   OR (required_date IS NOT NULL AND STR_TO_DATE(required_date, '%c/%e/%Y') IS NULL)
   OR (shipped_date IS NOT NULL AND STR_TO_DATE(shipped_date, '%c/%e/%Y') IS NULL);


-- =====================================================
-- ADD CLEAN DATE COLUMNS
-- =====================================================

-- Add properly formatted DATE columns for analysis
ALTER TABLE orders
ADD COLUMN order_date_clean DATE,
ADD COLUMN required_date_clean DATE,
ADD COLUMN shipped_date_clean DATE;


-- =====================================================
-- CONVERT RAW DATE STRINGS TO DATE FORMAT
-- =====================================================

SET SQL_SAFE_UPDATES = 0;

UPDATE orders
SET
    order_date_clean = STR_TO_DATE(order_date, '%c/%e/%Y'),
    required_date_clean = STR_TO_DATE(required_date, '%c/%e/%Y'),
    shipped_date_clean = STR_TO_DATE(shipped_date, '%c/%e/%Y');

SET SQL_SAFE_UPDATES = 1;


-- =====================================================
-- VERIFY DATE CONVERSION
-- =====================================================

SELECT
    order_id,
    order_date,
    order_date_clean,
    required_date,
    required_date_clean,
    shipped_date,
    shipped_date_clean
FROM orders
LIMIT 10;


-- =====================================================
-- LOGICAL DATA VALIDATION
-- =====================================================

-- Orders shipped before they were placed
SELECT *
FROM orders
WHERE shipped_date_clean IS NOT NULL
AND shipped_date_clean < order_date_clean;

-- Orders required before order date
SELECT *
FROM orders
WHERE required_date_clean IS NOT NULL
AND required_date_clean < order_date_clean;


-- =====================================================
-- ORDER ITEM VALIDATION
-- =====================================================

-- Check for invalid discounts
SELECT *
FROM order_items
WHERE discount < 0
   OR discount > 1;

-- Check for invalid quantities
SELECT *
FROM order_items
WHERE quantity <= 0;


-- =====================================================
-- INVENTORY VALIDATION
-- =====================================================

-- Identify negative inventory quantities
SELECT *
FROM stocks
WHERE quantity < 0;


-- =====================================================
-- DATA CLEANING SUMMARY
-- =====================================================
-- Steps performed:
-- 1. Validated missing customer data
-- 2. Replaced missing phone numbers with placeholder
-- 3. Validated order records
-- 4. Converted raw CSV date strings into proper DATE fields
-- 5. Verified successful date conversions
-- 6. Checked for logical data inconsistencies
-- 7. Validated product order quantities and discounts
-- 8. Checked inventory integrity
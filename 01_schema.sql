-- =====================================================
-- Bike Store Sales & Operations Analysis in MySQL
-- File: 01_schema.sql
-- Purpose: Create raw database schema for CSV import
-- MySQL Version: 8.0
-- =====================================================

CREATE DATABASE IF NOT EXISTS bike_store_db;
USE bike_store_db;

DROP TABLE IF EXISTS stocks;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS staffs;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS brands;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS stores;

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    first_name VARCHAR(15) NOT NULL,
    last_name VARCHAR(15) NOT NULL,
    phone VARCHAR(15),
    email VARCHAR(40),
    street VARCHAR(40),
    city VARCHAR(30),
    state VARCHAR(5),
    zip_code VARCHAR(10)
);

CREATE TABLE stores (
    store_id INT PRIMARY KEY,
    store_name VARCHAR(20) NOT NULL,
    phone VARCHAR(15),
    email VARCHAR(25),
    street VARCHAR(25),
    city VARCHAR(15),
    state VARCHAR(5),
    zip_code VARCHAR(10)
);

CREATE TABLE staffs (
    staff_id INT PRIMARY KEY,
    first_name VARCHAR(15) NOT NULL,
    last_name VARCHAR(15) NOT NULL,
    email VARCHAR(35) NOT NULL,
    phone VARCHAR(20),
    active TINYINT NOT NULL,
    store_id INT NOT NULL,
    manager_id INT,
    CONSTRAINT fk_staffs_store
        FOREIGN KEY (store_id) REFERENCES stores(store_id),
    CONSTRAINT fk_staffs_manager
        FOREIGN KEY (manager_id) REFERENCES staffs(staff_id)
);

-- Raw orders table: dates stored as text first for safe CSV import
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_status TINYINT NOT NULL,
    order_date VARCHAR(20) NOT NULL,
    required_date VARCHAR(20),
    shipped_date VARCHAR(20),
    store_id INT NOT NULL,
    staff_id INT NOT NULL,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_orders_store
        FOREIGN KEY (store_id) REFERENCES stores(store_id),
    CONSTRAINT fk_orders_staff
        FOREIGN KEY (staff_id) REFERENCES staffs(staff_id)
);

CREATE TABLE categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(25) NOT NULL
);

CREATE TABLE brands (
    brand_id INT PRIMARY KEY,
    brand_name VARCHAR(15) NOT NULL
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(60) NOT NULL,
    brand_id INT NOT NULL,
    category_id INT NOT NULL,
    model_year YEAR,
    list_price DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_products_brand
        FOREIGN KEY (brand_id) REFERENCES brands(brand_id),
    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

CREATE TABLE order_items (
    order_id INT NOT NULL,
    item_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    list_price DECIMAL(10,2) NOT NULL,
    discount DECIMAL(4,2) NOT NULL,
    PRIMARY KEY (order_id, item_id),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE stocks (
    store_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    PRIMARY KEY (store_id, product_id),
    CONSTRAINT fk_stocks_store
        FOREIGN KEY (store_id) REFERENCES stores(store_id),
    CONSTRAINT fk_stocks_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
);
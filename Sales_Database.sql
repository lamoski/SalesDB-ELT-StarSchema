--==============================================================
-- STEP 1: Create the database
--==============================================================
CREATE DATABASE SalesDB;
GO

USE SalesDB;
GO


--==============================================================
-- STEP 2: Create schemas for staging and analytics layers
--==============================================================
CREATE SCHEMA raw_data;     
GO
CREATE SCHEMA analytics;     
GO


--==============================================================
-- STEP 3: Verify schema creation
--==============================================================
SELECT name 
FROM sys.schemas 
WHERE name IN ('raw_data', 'analytics');


--==============================================================
-- STEP 4: Create staging table for raw sales data
--==============================================================
CREATE TABLE raw_data.Sales_Staging (
    Order_ID        VARCHAR(30),
    Amount          DECIMAL(12,2),
    Profit          DECIMAL(12,2),
    Quantity        INT,
    Category        VARCHAR(50),
    Sub_Category    VARCHAR(50),
    PaymentMode     VARCHAR(20),
    Order_Date      DATE,
    CustomerName    VARCHAR(50),
    State           VARCHAR(50),
    City            VARCHAR(50),
    Year_Month      VARCHAR(20)
);


--==============================================================
-- STEP 5: Load raw data into staging table
--==============================================================
INSERT INTO raw_data.Sales_Staging
SELECT * FROM [raw_data].[Sales Dataset];


--==============================================================
-- STEP 6: Drop temporary import table
--==============================================================
DROP TABLE [raw_data].[Sales Dataset];


--==============================================================
-- STEP 7: Validate row count in staging table
--==============================================================
SELECT COUNT(*) AS Row_Count
FROM raw_data.Sales_Staging;


--==============================================================
-- STEP 8: Check for duplicate Order_ID values
--==============================================================
SELECT Order_ID, COUNT(*) AS Duplicate_Count
FROM raw_data.Sales_Staging
GROUP BY Order_ID
HAVING COUNT(*) > 1;


--==============================================================
-- STEP 9: Check for NULL values in critical fields
--==============================================================
SELECT COUNT(*) AS Null_Count
FROM raw_data.Sales_Staging
WHERE Order_ID IS NULL
   OR Amount IS NULL
   OR Profit IS NULL
   OR Quantity IS NULL
   OR Category IS NULL
   OR Sub_Category IS NULL
   OR PaymentMode IS NULL
   OR Order_Date IS NULL
   OR CustomerName IS NULL
   OR State IS NULL
   OR City IS NULL
   OR Year_Month IS NULL;


--==============================================================
-- STEP 10: Add surrogate key to staging table
--==============================================================
ALTER TABLE raw_data.Sales_Staging
ADD Order_Key INT IDENTITY(1,1) PRIMARY KEY;



--==============================================================
-- STEP 11: Create FACT table (quantitative measures)
--==============================================================
CREATE TABLE analytics.Sales_Fact (
    Sales_Key INT IDENTITY(1,1) PRIMARY KEY,   
    Order_Key INT,                       
    Customer_Key INT,
    Product_Key INT,
    Date_Key INT,
    Amount DECIMAL(12,2),
    Profit DECIMAL(12,2),
    Quantity INT
);


--==============================================================
-- STEP 12: Create DIMENSION tables
--==============================================================

-- Customer Dimension
CREATE TABLE analytics.Customer_Dim (
    Customer_Key INT IDENTITY(1,1) PRIMARY KEY,
    Customer_Name VARCHAR(50),
    State VARCHAR(50),
    City VARCHAR(50)
);

-- Product Dimension
CREATE TABLE analytics.Product_Dim (
    Product_Key INT IDENTITY(1,1) PRIMARY KEY,
    Category VARCHAR(50),
    Sub_Category VARCHAR(50),
    Payment_Mode VARCHAR(20)
);

-- Date Dimension
CREATE TABLE analytics.Date_Dim (
    Date_Key INT IDENTITY(1,1) PRIMARY KEY,
    Order_Date DATE,
    Year_Month VARCHAR(20)
);


--==============================================================
-- STEP 13: Populate DIMENSION tables from staging
--==============================================================

-- Customer Dimension
INSERT INTO analytics.Customer_Dim (Customer_Name, State, City)
SELECT DISTINCT CustomerName, State, City
FROM raw_data.Sales_Staging;

-- Product Dimension
INSERT INTO analytics.Product_Dim (Category, Sub_Category, Payment_Mode)
SELECT DISTINCT Category, Sub_Category, PaymentMode
FROM raw_data.Sales_Staging;

-- Date Dimension
INSERT INTO analytics.Date_Dim (Order_Date, Year_Month)
SELECT DISTINCT Order_Date, Year_Month
FROM raw_data.Sales_Staging;


--==============================================================
-- STEP 14: Add additional date attributes
--==============================================================
ALTER TABLE analytics.Date_Dim
ADD Order_Date_Year INT,
    Order_Date_Month INT;

UPDATE analytics.Date_Dim
SET Order_Date_Year = YEAR(Order_Date),
    Order_Date_Month = MONTH(Order_Date);


--==============================================================
-- STEP 15: Populate FACT table using dimension keys
--==============================================================
INSERT INTO analytics.Sales_Fact (Order_Key, Customer_Key, Product_Key, Date_Key, Amount, Profit, Quantity)
SELECT 
    s.Order_Key,
    c.Customer_Key,
    p.Product_Key,
    d.Date_Key,
    s.Amount,
    s.Profit,
    s.Quantity
FROM raw_data.Sales_Staging s
JOIN analytics.Customer_Dim c 
    ON s.CustomerName = c.Customer_Name AND s.City = c.City
JOIN analytics.Product_Dim p 
    ON s.Category = p.Category AND s.Sub_Category = p.Sub_Category AND s.PaymentMode = p.PaymentMode
JOIN analytics.Date_Dim d 
    ON s.Order_Date = d.Order_Date;


--==============================================================
-- STEP 16: Create indexes for performance optimization
--==============================================================

-- Fact Table Indexes
CREATE INDEX idx_sales_customer ON analytics.Sales_Fact(Customer_Key);
CREATE INDEX idx_sales_product ON analytics.Sales_Fact(Product_Key);
CREATE INDEX idx_sales_date ON analytics.Sales_Fact(Date_Key);

-- Dimension Table Indexes
CREATE INDEX idx_customer_city ON analytics.Customer_Dim(City);
CREATE INDEX idx_customer_state ON analytics.Customer_Dim(State);
CREATE INDEX idx_product_category ON analytics.Product_Dim(Category);
CREATE INDEX idx_product_subcategory ON analytics.Product_Dim(Sub_Category);
CREATE INDEX idx_date_year ON analytics.Date_Dim(Order_Date_Year);
CREATE INDEX idx_date_month ON analytics.Date_Dim(Order_Date_Month);


--==============================================================
-- STEP 17: Add foreign key constraints for data integrity
--==============================================================
ALTER TABLE analytics.Sales_Fact
ADD CONSTRAINT FK_SalesFact_Customer
FOREIGN KEY (Customer_Key) REFERENCES analytics.Customer_Dim(Customer_Key);

ALTER TABLE analytics.Sales_Fact
ADD CONSTRAINT FK_SalesFact_Product
FOREIGN KEY (Product_Key) REFERENCES analytics.Product_Dim(Product_Key);

ALTER TABLE analytics.Sales_Fact
ADD CONSTRAINT FK_SalesFact_Date
FOREIGN KEY (Date_Key) REFERENCES analytics.Date_Dim(Date_Key);

ALTER TABLE analytics.Sales_Fact
ADD CONSTRAINT FK_SalesFact_Order
FOREIGN KEY (Order_Key) REFERENCES raw_data.Sales_Staging(Order_Key);





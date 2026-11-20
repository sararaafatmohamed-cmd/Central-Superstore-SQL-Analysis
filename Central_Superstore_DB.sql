--Create Database
Create Database Central_Superstore_DB

--USE Database
use Central_Superstore_DB

-- Create Schema's: raw--> raw data, stg-->Cleaning, dw-->Final Cleaned Data (ready for analysis)
Create Schema raw;
Create Schema stg;
Create Schema dw;
----------------------------------------------------------------------------------------
--Checking the Imported Data
Select * from raw.Central_Superstore
----------------------------------------------------------------------------------------
-- Transfer Data from raw to stg (for cleaning)
SELECT * INTO stg.Central_Superstore FROM raw.Central_Superstore
-------------------------------------------------------------------------------------------
-- Strarting Cleaning by Process the Nulls

select * from stg.Central_Superstore

SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'Central_Superstore';


ALTER TABLE stg.Central_Superstore
ALTER COLUMN Sales DECIMAL(18,2);

Alter table stg.Central_Superstore
Alter Column Profit DECIMAL(18,2);

ALTER TABLE stg.Central_Superstore
ALTER COLUMN Discount DECIMAL(5,2);

-- Check NULL Values
SELECT
    COUNT(*) AS Total_Rows,
    SUM(CASE WHEN Customer_ID IS NULL THEN 1 ELSE 0 END) AS Null_Customer_ID,
    SUM(CASE WHEN Customer_Name IS NULL THEN 1 ELSE 0 END) AS Null_Customer_Name,
    SUM(CASE WHEN Product_ID IS NULL THEN 1 ELSE 0 END) AS Null_Product_ID,
    SUM(CASE WHEN Product_Name IS NULL THEN 1 ELSE 0 END) AS Null_Product_Name,
    SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS Null_Category,
    SUM(CASE WHEN Sub_Category IS NULL THEN 1 ELSE 0 END) AS Null_Sub_Category,
    SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS Null_Country,
    SUM(CASE WHEN Region IS NULL THEN 1 ELSE 0 END) AS Null_Region,
    SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) AS Null_State,
    SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END) AS Null_City,
    SUM(CASE WHEN Postal_Code IS NULL THEN 1 ELSE 0 END) AS Null_Postal_Code
FROM stg.Central_Superstore;

--Check Duplicate Rows
SELECT
    Row_ID,
    COUNT(*) AS Duplicate_Count
FROM stg.Central_Superstore
GROUP BY Row_ID
HAVING COUNT(*) > 1;

-- Inspect NULL Sales Records
SELECT *
FROM stg.Central_Superstore
WHERE Sales IS NULL;


-- Replace NULL Sales with 0

UPDATE stg.Central_Superstore
SET Sales = 0
WHERE Sales IS NULL;

-----------------------------------------------------------------------------------------
--create fact& dim tables:
---Dim_Customer Table

-- Check Customer Data
SELECT
    Customer_ID,
    COUNT(DISTINCT Customer_Name) AS Name_Count,
    COUNT(DISTINCT Segment) AS Segment_Count
FROM stg.Central_Superstore
GROUP BY Customer_ID
HAVING COUNT(DISTINCT Customer_Name) > 1
    OR COUNT(DISTINCT Segment) > 1;

---Check Customer ID NULL
SELECT *
FROM stg.Central_Superstore
WHERE Customer_ID IS NULL;


Create Table dw.Dim_Customer(
Customer_ID varchar(50) primary key,
Customer_Name nvarchar(100),
Segment nvarchar(50));

INSERT INTO dw.Dim_Customer
(
    Customer_ID,
    Customer_Name,
    Segment
)
SELECT DISTINCT
    Customer_ID,
    Customer_Name,
    Segment
FROM stg.Central_Superstore;


-- Check Customer Dimension

SELECT *FROM dw.Dim_Customer;

-------------------------------------------------------------------------------
---Dim_Date Table

-- Create Dim_Date Table
CREATE TABLE dw.Dim_Date
(
    Full_Date DATE PRIMARY KEY,
    Year INT,
    Quarter INT,
    Month INT,
    Month_Name NVARCHAR(20),
    Day INT,
    Day_Name NVARCHAR(20)
);

--insert data
INSERT INTO dw.Dim_Date
(
    Full_Date,
    Year,
    Quarter,
    Month,
    Month_Name,
    Day,
    Day_Name
)
SELECT DISTINCT
    CAST(Order_Date AS DATE),
    YEAR(Order_Date),
    DATEPART(QUARTER, Order_Date),
    MONTH(Order_Date),
    DATENAME(MONTH, Order_Date),
    DAY(Order_Date),
    DATENAME(WEEKDAY, Order_Date)
FROM stg.Central_Superstore
WHERE Order_Date IS NOT NULL;

Select * from dw.Dim_Date
-----------------------------------------------------------------------------
--Dim_Product
----Check Product Data
SELECT
    Product_ID,
    COUNT(DISTINCT Product_Name) AS Name_Count,
    COUNT(DISTINCT Category) AS Category_Count,
    COUNT(DISTINCT Sub_Category) AS Sub_Category_Count
FROM stg.Central_Superstore
GROUP BY Product_ID
HAVING
    COUNT(DISTINCT Product_Name) > 1
    OR COUNT(DISTINCT Category) > 1
    OR COUNT(DISTINCT Sub_Category) > 1;
---Create Dim_Product
CREATE TABLE dw.Dim_Product
(
    Product_ID NVARCHAR(50),
    Product_Name NVARCHAR(255),
    Category NVARCHAR(100),
    Sub_Category NVARCHAR(100)
	 CONSTRAINT PK_Dim_Product
    PRIMARY KEY (Product_ID, Product_Name)
);

SELECT DISTINCT
    Product_ID,
    Product_Name,
    Category,
    Sub_Category
FROM stg.Central_Superstore
WHERE Product_ID IN
(
    SELECT Product_ID
    FROM stg.Central_Superstore
    GROUP BY Product_ID
    HAVING COUNT(DISTINCT Product_Name) > 1
)
ORDER BY Product_ID, Product_Name;

-- Insert Distinct Product
INSERT INTO dw.Dim_Product
(
    Product_ID,
    Product_Name,
    Category,
    Sub_Category
)
SELECT DISTINCT
    Product_ID,
    Product_Name,
    Category,
    Sub_Category
FROM stg.Central_Superstore;

SELECT *FROM dw.Dim_Product;

-- Validate Dim_Product
SELECT
    Product_ID,
    Product_Name,
    COUNT(*) AS Duplicate_Count
FROM dw.Dim_Product
GROUP BY
    Product_ID,
    Product_Name
HAVING COUNT(*) > 1;

---------------------------------------------------------
--Dim _Location

-- Check Location Data

SELECT
    Country,
    Region,
    State,
    City,
    Postal_Code,
    COUNT(*) AS Record_Count
FROM stg.Central_Superstore
GROUP BY
    Country,
    Region,
    State,
    City,
    Postal_Code
ORDER BY Country, Region, State, City;

-- Check Postal_Code
SELECT
    Postal_Code,
    COUNT(DISTINCT City) AS City_Count,
    COUNT(DISTINCT State) AS State_Count,
    COUNT(DISTINCT Region) AS Region_Count
FROM stg.Central_Superstore
GROUP BY Postal_Code
HAVING
    Postal_Code IS NULL
    OR COUNT(DISTINCT City) > 1
    OR COUNT(DISTINCT State) > 1
    OR COUNT(DISTINCT Region) > 1;

-- Create Location Dimension
CREATE TABLE dw.Dim_Location
(
   Postal_Code NVARCHAR(20) PRIMARY KEY,
    Region NVARCHAR(100),
    State NVARCHAR(100),
    City NVARCHAR(100),
);

--Insert Without Duplicates
INSERT INTO dw.Dim_Location
(
    Postal_Code,
    Region,
    State,
    City
)
SELECT DISTINCT
    Postal_Code,
    Region,
    State,
    City
FROM stg.Central_Superstore;

ALTER TABLE dw.Dim_Location
DROP COLUMN Region;

SELECT *FROM dw.Dim_Location;

--------------------------------------------------
-- Fact Table 
-- Check Source Columns Before Creating Fact_Sales
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'Central_Superstore'
ORDER BY ORDINAL_POSITION;

-- Create Fact_Sales Table
-- Connecting Fact_Sales with Dimension Tables

CREATE TABLE dw.Fact_Sales
(
    Row_ID INT PRIMARY KEY,
    Order_ID NVARCHAR(50),
    Order_Date DATE FOREIGN KEY REFERENCES dw.Dim_Date(Full_Date),
    Ship_Date DATE,
    Ship_Mode NVARCHAR(50),
    Customer_ID VARCHAR(50) FOREIGN KEY REFERENCES dw.Dim_Customer(Customer_ID),
    Product_ID NVARCHAR(50),
    Product_Name NVARCHAR(255),
    Postal_Code NVARCHAR(20)FOREIGN KEY REFERENCES dw.Dim_Location(Postal_Code),
    Sales DECIMAL(18,2),
    Quantity INT,
    Discount DECIMAL(5,2),
    Profit DECIMAL(18,2),

    CONSTRAINT FK_Fact_Product
        FOREIGN KEY (Product_ID, Product_Name)
        REFERENCES dw.Dim_Product(Product_ID, Product_Name)
);

-- Insert Data into Fact_Sales

INSERT INTO dw.Fact_Sales
(
    Row_ID,
    Order_ID,
    Order_Date,
    Ship_Date,
    Ship_Mode,
    Customer_ID,
    Product_ID,
    Product_Name,
    Postal_Code,
    Sales,
    Quantity,
    Discount,
    Profit
)
SELECT
    s.Row_ID,
    s.Order_ID,
    CAST(s.Order_Date AS DATE),
    CAST(s.Ship_Date AS DATE),
    s.Ship_Mode,
    s.Customer_ID,
    s.Product_ID,
    s.Product_Name,
    s.Postal_Code,
    s.Sales,
    s.Quantity,
    s.Discount,
    s.Profit

FROM stg.Central_Superstore s;

SELECT *FROM dw.Fact_Sales;

------------------------------------------------------------------------
---Data Validation
-- Compare Row Count Between Stg and Fact_Sales

SELECT COUNT(*) AS Fact_Rows
FROM dw.Fact_Sales;

SELECT COUNT(*) AS Staging_Rows
FROM stg.Central_Superstore;

-- Check Duplicate Rows in Fact_Sales

SELECT
    Row_ID,
    COUNT(*) AS Duplicate_Count
FROM dw.Fact_Sales
GROUP BY Row_ID
HAVING COUNT(*) > 1;

-- Check NULL Values in Fact_Sales

SELECT *
FROM dw.Fact_Sales
WHERE Customer_ID IS NULL
   OR Order_Date IS NULL
   OR Postal_Code IS NULL
   OR Product_ID IS NULL
   OR Product_Name IS NULL;
--------------------------------------------------------------
---SQL Data Analysis

-- Sales Analysis

-- Calculate Overall Sales KPIs

SELECT
    COUNT(*) AS Total_Records,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    SUM(Sales) AS Total_Sales,
    SUM(Quantity) AS Total_Quantity,
    AVG(Sales) AS Average_Sales_Per_Row
FROM dw.Fact_Sales;

-- Calculate Total Sales by Year

SELECT
    YEAR(Order_Date) AS Sales_Year,
    SUM(Sales) AS Total_Sales,
    SUM(Quantity) AS Total_Quantity
FROM dw.Fact_Sales
GROUP BY YEAR(Order_Date)
ORDER BY Sales_Year;

-- Calculate Total Sales by Quarter

SELECT
    YEAR(Order_Date) AS Sales_Year,
    DATEPART(QUARTER, Order_Date) AS Sales_Quarter,
    SUM(Sales) AS Total_Sales
FROM dw.Fact_Sales
GROUP BY
    YEAR(Order_Date),
    DATEPART(QUARTER, Order_Date)
ORDER BY
    Sales_Year,
    Sales_Quarter;

-- Calculate Total Sales by Month

SELECT
    YEAR(Order_Date) AS Sales_Year,
    MONTH(Order_Date) AS Sales_Month,
    DATENAME(MONTH, Order_Date) AS Month_Name,
    SUM(Sales) AS Total_Sales
FROM dw.Fact_Sales
GROUP BY
    YEAR(Order_Date),
    MONTH(Order_Date),
    DATENAME(MONTH, Order_Date)
ORDER BY
    Sales_Year,
    Sales_Month;


-- Identify Top 10 Best-Selling Orders

SELECT TOP 10
    Order_ID,
    SUM(Sales) AS Total_Sales
FROM dw.Fact_Sales
GROUP BY Order_ID
ORDER BY Total_Sales DESC;

-- Identify Top 10 Best-Selling Products

SELECT TOP 10
    Product_ID,
    Product_Name,
    SUM(Sales) AS Total_Sales,
    SUM(Quantity) AS Total_Quantity
FROM dw.Fact_Sales
GROUP BY
    Product_ID,
    Product_Name
ORDER BY Total_Sales DESC;

-- Analyze Sales by Ship Mode

SELECT
    Ship_Mode,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    SUM(Sales) AS Total_Sales,
    AVG(Sales) AS Average_Sales
FROM dw.Fact_Sales
GROUP BY Ship_Mode
ORDER BY Total_Sales DESC;

-- Analyze Sales by Order Day

SELECT
    DATENAME(WEEKDAY, Order_Date) AS Order_Day,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    SUM(Sales) AS Total_Sales
FROM dw.Fact_Sales
GROUP BY DATENAME(WEEKDAY, Order_Date)
ORDER BY Total_Sales DESC;
------------------------------------------------------------------------------------
--Profit Analysis
--Calculate Overall Profit KPIs
SELECT
    SUM(Profit) AS Total_Profit,
    SUM(Sales) AS Total_Sales,
    SUM(Quantity) AS Total_Quantity,
    AVG(Profit) AS Average_Profit
FROM dw.Fact_Sales;

--Calculate Overall Profit Margin
SELECT
    SUM(Profit) AS Total_Profit,
    SUM(Sales) AS Total_Sales,
    (SUM(Profit) / NULLIF(SUM(Sales), 0)) * 100 AS Profit_Margin_Percentage
FROM dw.Fact_Sales;

--  Calculate Total Profit by Year
SELECT
    YEAR(Order_Date) AS Sales_Year,
    SUM(Profit) AS Total_Profit,
    SUM(Sales) AS Total_Sales,
    (SUM(Profit) / NULLIF(SUM(Sales), 0)) * 100 AS Profit_Margin_Percentage
FROM dw.Fact_Sales
GROUP BY YEAR(Order_Date)
ORDER BY Sales_Year;

--Calculate Total Profit by Quarter
SELECT
    YEAR(Order_Date) AS Sales_Year,
    DATEPART(QUARTER, Order_Date) AS Sales_Quarter,
    SUM(Profit) AS Total_Profit,
    SUM(Sales) AS Total_Sales
FROM dw.Fact_Sales
GROUP BY
    YEAR(Order_Date),
    DATEPART(QUARTER, Order_Date)
ORDER BY Sales_Year, Sales_Quarter;

--Calculate Total Profit by Month
SELECT
    YEAR(Order_Date) AS Sales_Year,
    MONTH(Order_Date) AS Sales_Month,
    DATENAME(MONTH, Order_Date) AS Month_Name,
    SUM(Profit) AS Total_Profit,
    SUM(Sales) AS Total_Sales
FROM dw.Fact_Sales
GROUP BY
    YEAR(Order_Date),
    MONTH(Order_Date),
    DATENAME(MONTH, Order_Date)
ORDER BY Sales_Year, Sales_Month;

-- Identify Top 10 Most Profitable Products
SELECT TOP 10
    Product_ID,
    Product_Name,
    SUM(Profit) AS Total_Profit,
    SUM(Sales) AS Total_Sales
FROM dw.Fact_Sales
GROUP BY Product_ID, Product_Name
ORDER BY Total_Profit DESC;

-- Identify Loss-Making Products
SELECT
    Product_ID,
    Product_Name,
    SUM(Profit) AS Total_Profit,
    SUM(Sales) AS Total_Sales
FROM dw.Fact_Sales
GROUP BY Product_ID, Product_Name
HAVING SUM(Profit) < 0
ORDER BY Total_Profit;

--  Identify Loss-Making Orders
SELECT
    Order_ID,
    SUM(Profit) AS Total_Profit,
    SUM(Sales) AS Total_Sales
FROM dw.Fact_Sales
GROUP BY Order_ID
HAVING SUM(Profit) < 0
ORDER BY Total_Profit;

-- Analyze Profit by Ship Mode
SELECT
    Ship_Mode,
    SUM(Profit) AS Total_Profit,
    SUM(Sales) AS Total_Sales,
    (SUM(Profit) / NULLIF(SUM(Sales), 0)) * 100 AS Profit_Margin_Percentage
FROM dw.Fact_Sales
GROUP BY Ship_Mode
ORDER BY Total_Profit DESC;

----------------------------------------------------------------------------------------
---Customer Analysis

-- Calculate Total Number of Customers
SELECT
    COUNT(*) AS Total_Customers
FROM dw.Dim_Customer;

-- Analyze Sales and Profit by Customer Segment
SELECT
    C.Segment,
    COUNT(DISTINCT F.Customer_ID) AS Total_Customers,
    COUNT(DISTINCT F.Order_ID) AS Total_Orders,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit
FROM dw.Fact_Sales F
JOIN dw.Dim_Customer C
    ON F.Customer_ID = C.Customer_ID
GROUP BY C.Segment
ORDER BY Total_Sales DESC;

-- Identify Top 10 Customers by Sales
SELECT TOP 10
    C.Customer_ID,
    C.Customer_Name,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit,
    COUNT(DISTINCT F.Order_ID) AS Total_Orders
FROM dw.Fact_Sales F
JOIN dw.Dim_Customer C
    ON F.Customer_ID = C.Customer_ID
GROUP BY C.Customer_ID, C.Customer_Name
ORDER BY Total_Sales DESC;

-- Identify Top 10 Customers by Profit
SELECT TOP 10
    C.Customer_ID,
    C.Customer_Name,
    SUM(F.Profit) AS Total_Profit,
    SUM(F.Sales) AS Total_Sales
FROM dw.Fact_Sales F
JOIN dw.Dim_Customer C
    ON F.Customer_ID = C.Customer_ID
GROUP BY C.Customer_ID, C.Customer_Name
ORDER BY Total_Profit DESC;

-- Analyze Customer Orders and Average Sales
SELECT
    C.Customer_ID,
    C.Customer_Name,
    COUNT(DISTINCT F.Order_ID) AS Total_Orders,
    SUM(F.Sales) AS Total_Sales,
    AVG(F.Sales) AS Average_Sales
FROM dw.Fact_Sales F
JOIN dw.Dim_Customer C
    ON F.Customer_ID = C.Customer_ID
GROUP BY C.Customer_ID, C.Customer_Name
ORDER BY Total_Orders DESC;
-----------------------------------------------------------------------------------------
--Product Analysis

-- Analyze Sales and Profit by Category
SELECT
    P.Category,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit,
    SUM(F.Quantity) AS Total_Quantity
FROM dw.Fact_Sales F
JOIN dw.Dim_Product P
    ON F.Product_ID = P.Product_ID
    AND F.Product_Name = P.Product_Name
GROUP BY P.Category
ORDER BY Total_Sales DESC;

-- Analyze Sales and Profit by Sub-Category
SELECT
    P.Category,
    P.Sub_Category,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit,
    SUM(F.Quantity) AS Total_Quantity
FROM dw.Fact_Sales F
JOIN dw.Dim_Product P
    ON F.Product_ID = P.Product_ID
    AND F.Product_Name = P.Product_Name
GROUP BY P.Category, P.Sub_Category
ORDER BY Total_Sales DESC;

-- Identify Top 10 Products by Sales
SELECT TOP 10
    F.Product_ID,
    F.Product_Name,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit,
    SUM(F.Quantity) AS Total_Quantity
FROM dw.Fact_Sales F
GROUP BY F.Product_ID, F.Product_Name
ORDER BY Total_Sales DESC;

-- Identify Top 10 Products by Profit
SELECT TOP 10
    F.Product_ID,
    F.Product_Name,
    SUM(F.Profit) AS Total_Profit,
    SUM(F.Sales) AS Total_Sales
FROM dw.Fact_Sales F
GROUP BY F.Product_ID, F.Product_Name
ORDER BY Total_Profit DESC;

-- Identify Bottom 10 Products by Sales
SELECT TOP 10
    F.Product_ID,
    F.Product_Name,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit
FROM dw.Fact_Sales F
GROUP BY F.Product_ID, F.Product_Name
ORDER BY Total_Sales ASC;

--  dentify Bottom 10 Products by Profit
SELECT TOP 10
    F.Product_ID,
    F.Product_Name,
    SUM(F.Profit) AS Total_Profit,
    SUM(F.Sales) AS Total_Sales
FROM dw.Fact_Sales F
GROUP BY F.Product_ID, F.Product_Name
ORDER BY Total_Profit ASC;
-----------------------------------------------------------------------------------------
---Location Analysis

-- Analyze Sales and Profit by State
SELECT
    L.State,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit,
    SUM(F.Quantity) AS Total_Quantity
FROM dw.Fact_Sales F
JOIN dw.Dim_Location L
    ON F.Postal_Code = L.Postal_Code
GROUP BY L.State
ORDER BY Total_Sales DESC;

-- Analyze Sales and Profit by City
SELECT
    L.City,
    L.State,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit,
    SUM(F.Quantity) AS Total_Quantity
FROM dw.Fact_Sales F
JOIN dw.Dim_Location L
    ON F.Postal_Code = L.Postal_Code
GROUP BY L.City, L.State
ORDER BY Total_Sales DESC;

-- Identify Top 10 States by Sales
SELECT TOP 10
    L.State,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit
FROM dw.Fact_Sales F
JOIN dw.Dim_Location L
    ON F.Postal_Code = L.Postal_Code
GROUP BY L.State
ORDER BY Total_Sales DESC;

-- Identify Top 10 Cities by Sales
SELECT TOP 10
    L.City,
    L.State,
    SUM(F.Sales) AS Total_Sales,
    SUM(F.Profit) AS Total_Profit
FROM dw.Fact_Sales F
JOIN dw.Dim_Location L
    ON F.Postal_Code = L.Postal_Code
GROUP BY L.City, L.State
ORDER BY Total_Sales DESC;
-----------------------------------------------------------------------------------------
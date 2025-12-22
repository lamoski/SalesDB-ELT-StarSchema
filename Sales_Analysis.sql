--========================================================================
				---SALES PERFORMANCE 
--========================================================================
--1. Total Sales, Profit, and Profit Margin
---BUSINESS LOGIC:
--Calculates overall business performance by summarizing total revenue,
--total profit and profit margin

SELECT SUM(Amount) as Total_Sales_Revenue,SUM(Profit) as Total_Profit,
CAST(SUM(Profit)/SUM(Amount) AS DECIMAL(10,2)) as Profit_Margin
FROM Analytics.Sales_Fact

--2. Profit Margin Across Sub_Categories
---BUSINESS LOGIC:
--Identifies which sub_categories generate the highest profit margin

SELECT p.Sub_Category,CONCAT(CAST(SUM(s.Profit)/SUM(s.Amount)*100 as DECIMAL(10,2)),'%') as Profit_Margin
FROM Analytics.Sales_Fact s
LEFT JOIN Analytics.Product_Dim p on s.Product_Key = p.Product_key
GROUP BY p.Sub_Category
ORDER BY CAST(SUM(s.Profit)/SUM(s.Amount)*100 as DECIMAL(10,2)) DESC

--3. Highest Revenue by Sub_Category
---BUSINESS LOGIC:
--Ranks sub_categories by total revenue and profit margin

SELECT p.Sub_Category,
SUM(s.Amount) as Total_Sales_Revenue,
SUM(s.Profit) as Total_Profit,
CONCAT(CAST(SUM(s.Profit)*1.0/SUM(s.Amount)*100 as DECIMAL(10,2)),'%') as Profit_Margin
FROM Analytics.Sales_Fact s
LEFT JOIN Analytics.Product_Dim p on s.Product_Key = p.Product_key
GROUP BY p.Sub_Category
ORDER BY Total_Sales_Revenue DESC,CAST(SUM(s.Profit)*1.0/SUM(s.Amount)*100 as DECIMAL(10,2)) DESC

--========================================================================
					--SALES TRENDS
--========================================================================
--4. Monthly Sales Trend
---BUSINESS LOGIC:
--Shows how revenue changes month-to-month across years

SELECT YEAR(d.Order_Date) as Year,
MONTH(d.Order_Date) as Month,
DATENAME(MONTH,d.Order_Date) as Month_Name,
SUM(s.Amount) as Total_Revenue_By_Month from Analytics.Sales_Fact s
LEFT JOIN Analytics.Date_Dim d ON s.date_key = d.date_key
GROUP BY YEAR(d.Order_Date),MONTH(d.Order_Date),DATENAME(MONTH,d.Order_Date)
ORDER BY YEAR(d.Order_Date), MONTH(d.Order_Date)


--5. Quaterly Sales Trend
---BUSINESS LOGIC:
--Summarizes revenue by quater to provide a higher_level view of performance

SELECT YEAR(d.order_date) as Year,
CONCAT('Q',DATEPART(QUARTER,d.Order_Date)) as Quarter,
SUM(s.Amount) as Amount FROM Analytics.Sales_Fact s
LEFT JOIN Analytics.Date_Dim d ON s.date_key = d.date_key
GROUP BY YEAR(d.order_date),
DATEPART(QUARTER,d.Order_Date)
ORDER BY YEAR(d.order_date),DATEPART(QUARTER,d.Order_Date) 


--========================================================================
				--CUSTOMER ANALYSIS
--========================================================================
--6. Top 10 Customers by Revenue
---BUSINESS LOGIC:
--Identifies the highest-values customers
SELECT  c.Customer_Name,SUM(Amount) as Amount FROM Analytics.Sales_Fact s
LEFT JOIN Analytics.Customer_Dim c ON s.Customer_Key = c.Customer_Key
GROUP BY c.Customer_Name
ORDER BY Amount DESC
OFFSET 0 rows FETCH NEXT 10 ROWS ONLY



SELECT * FROM analytics.SALES_FACT
--7. Percent of Revenue from Top 20% Customers
---BUSINESS LOGIC:
--Applies the Pareto Principle (80/20 rule) to measure customer concentration

WITH CustomerRevenue as 
(SELECT c.Customer_Key,SUM(s.Amount) as Revenue FROM Analytics.Sales_Fact s
LEFT JOIN Analytics.Customer_Dim c ON s.Customer_Key = c.Customer_Key
GROUP BY c.Customer_Key),
RANKED as 
(SELECT Customer_Key,
Revenue,
NTILE(5) OVER (ORDER BY Revenue DESC) AS Tile
FROM CustomerRevenue)

SELECT CONCAT(CAST(SUM(CASE WHEN Tile=1 THEN Revenue END) *1.0
/SUM(Revenue)*100 as DECIMAL(10,2)),'%') as Percent_From_Top_20_Customers from ranked


--========================================================================
				--GEOGRAPHIC ANALYSIS
--========================================================================
--8. Revenue by Region(State)
---BUSINESS LOGIC:
--Shows which regions contribute the most revenue
SELECT c.State,SUM(s.Amount) as Revenue,
CONCAT(CAST(SUM(s.Amount)*1.0/(SELECT SUM(Amount)FROM Analytics.Sales_Fact)*100 as DECIMAL(12,2)),'%') as Percent_Contribution
FROM Analytics.Sales_Fact s
LEFT JOIN Analytics.Customer_Dim c ON s.Customer_Key = c.Customer_Key
GROUP BY c.State
ORDER BY SUM(s.Amount) DESC

--9. Revenue by City
---BUSINESS LOGIC:
--Identifies top_performing cities and local markets

SELECT c.City,SUM(s.Amount) as Revenue,
CONCAT(CAST(SUM(s.Amount)*1.0/(SELECT SUM(Amount)  FROM  Analytics.Sales_Fact)*100 as DECIMAL(13,2)),'%') Percent_Contribution
FROM Analytics.Sales_Fact s
LEFT JOIN Analytics.Customer_Dim c ON s.Customer_Key = c.Customer_Key
GROUP BY c.City
ORDER BY SUM(s.Amount) DESC


--========================================================================
				--PRODUCT ANALYSIS
--========================================================================
--10.Fastest-Growing Product Categories
--BUSINESS LOGIC:
--Measures month-over-month revenue growth for each category

WITH MonthlySalesCategory as 
(SELECT p.Category,d.Order_Date_Year,d.Order_Date_Month, SUM(s.Amount) as Monthly_Revenue  FROM Analytics.Sales_Fact s 
LEFT JOIN Analytics.Product_Dim p ON s.Product_Key = p.Product_Key
LEFT JOIN Analytics.Date_Dim d ON s.Date_Key = d.Date_Key
GROUP BY  p.Category,d.Order_Date_Year,d.Order_Date_Month) ,

Growth as (SELECT Category,
Order_Date_Year,
Order_Date_Month,
Monthly_Revenue,
LAG(Monthly_Revenue) OVER (PARTITION BY Category ORDER BY Order_Date_Year,
Order_Date_Month)as Previous_Month_Revenue  
FROM MonthlySalesCategory
)

SELECT Category,
Order_Date_Year,
Order_Date_Month,
Monthly_Revenue,
Previous_Month_Revenue,
CONCAT(CAST((( Monthly_Revenue-Previous_Month_Revenue)*1.0/ nullif(Previous_Month_Revenue,0) *100) as DECIMAL(13,2)),'%') as Growth_Rate_Percent
FROM Growth
WHERE Previous_Month_Revenue > 100
ORDER BY  CAST((( Monthly_Revenue-Previous_Month_Revenue)*1.0/ nullif(Previous_Month_Revenue,0) *100) as DECIMAL(13,2)) DESC

--11.Underperforming Sub_Categories
--BUSINESS LOGIC:
--Identifies the lowest-margin sub_categories
SELECT  p.Sub_Category, SUM(s.Amount) as Revenue, SUM(s.Profit) as Profit,
CONCAT(CAST(SUM(s.Profit)*1.0/SUM(s.Amount) * 100 as DECIMAL(13,2)),'%') as Profit_Margin FROM Analytics.Sales_Fact s
LEFT JOIN Analytics.Product_Dim p on s.Product_Key = p.Product_key
GROUP BY p.Sub_Category 
ORDER BY CAST(SUM(s.Profit)*1.0/SUM(s.Amount) * 100 as DECIMAL(13,2)) ASC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY

--========================================================================
				--PAYMENT ANALYSIS
--========================================================================
--12.Sales Performance by Payment Method
--BUSINESS LOGIC:
--Compares performance across payment modes(debit card,credit card,UPI,COD,EMI)
SELECT p.Payment_Mode,
count(*) as Order_Count,
SUM(s.Amount) as Total_Revenue,
SUM(s.Profit) as Total_Profit,
CONCAT(CAST(SUM(s.Profit)*1.0/SUM(s.Amount) * 100 as DECIMAL(13,2)),'%') as Profit_Margin,
CAST(AVG(s.Amount) as DECIMAL(12,2)) as Avg_Order_Value
FROM Analytics.Sales_Fact s
LEFT JOIN Analytics.Product_Dim p on s.Product_Key = p.Product_key
GROUP BY p.Payment_Mode 
ORDER BY Total_Revenue DESC
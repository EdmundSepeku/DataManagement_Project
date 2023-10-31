CREATE OR REPLACE VIEW employee1 AS
SELECT T1.EmployeeID, T1.FirstName, T1.LastName, STR_TO_DATE(T1.HireDate, '%m/%d/%Y') AS HireDate, oquery.Orders, oquery.Customers, 
oquery.Average_Process_Time AS Average_Days_Before_Req, money.Total_Revenue, 
money.Units_Sold, cat.Most_Sold_Product, cat.Most_Sold_Category,UnitsSold as Most_Sold_Product_Units, terquery.Territories
FROM employees T1
JOIN (
    SELECT EmployeeID, COUNT(DISTINCT CustomerID) as Customers, COUNT(OrderID) AS Orders, ROUND(AVG(days_bef_or_aft_req), 2) AS Average_Process_Time
    FROM (
        SELECT *, DATEDIFF(RequiredDate, ShippedDate) AS days_bef_or_aft_req
        FROM (
            SELECT OrderID, CustomerID, EmployeeID, STR_TO_DATE(RequiredDate, '%m/%d/%Y') AS RequiredDate, STR_TO_DATE(ShippedDate, '%m/%d/%Y') AS ShippedDate, ShipCountry
            FROM orders
        ) tab1
    ) tab2
    GROUP BY EmployeeID
) oquery ON T1.EmployeeID = oquery.EmployeeID
JOIN (
    SELECT EmployeeID, COUNT(TerritoryID) AS Territories
    FROM employeeterritories
    GROUP BY EmployeeID
) terquery ON T1.EmployeeID = terquery.EmployeeID
JOIN (
	  SELECT EmployeeID,
		   ROUND(SUM(UnitPrice * Quantity) - SUM(Discount * (UnitPrice * Quantity))) AS Total_Revenue,
		   SUM(Quantity) AS Units_Sold
	  FROM (
		SELECT o.EmployeeID, d.UnitPrice, d.Quantity, d.Discount
		FROM orders o
		JOIN order_details d ON o.OrderID = d.OrderID
	      ) AS tabh
	GROUP BY EmployeeID
   ) money ON T1.EmployeeID = money.EmployeeID
JOIN (
    SELECT EmployeeID, ProductName AS Most_Sold_Product, CategoryName AS Most_Sold_Category, UnitsSold
	FROM (
	SELECT EmployeeID, ProductName, CategoryName, SUM(ProdQty) as UnitsSold,
               ROW_NUMBER() OVER (PARTITION BY EmployeeID ORDER BY SUM(ProdQty) DESC) AS rn
        FROM orders o
        JOIN (
            SELECT d.OrderID, d.ProductID, p.CategoryID, ProductName,Quantity as ProdQty, CategoryName
            FROM products p
            JOIN order_details d ON p.ProductID = d.ProductID
            JOIN categories c ON p.CategoryID = c.CategoryID
        ) tab4 ON o.OrderID = tab4.OrderID
        GROUP BY EmployeeID, ProductName, CategoryName
        ) tab5
    WHERE rn = 1
) cat ON T1.EmployeeID = cat.EmployeeID;

SELECT * FROM employee1;

-- Queries

-- Query 1 Most frequent Customer
SELECT FirstName,LastName,Most_Frequent_Customer, Freq AS Frequency,ROUND(100*(Freq/Orders),2) Frequency_Percentage FROM
employee1 e 
JOIN (
	SELECT EmployeeID,CompanyName as Most_Frequent_Customer,Freq FROM (SElECT EmployeeID,CompanyName,COUNT(CompanyName) as Freq FROM orders o
	JOIN customers c ON o.CustomerID=c.CustomerID
	GROUP BY EmployeeID,CompanyName) tab7
	WHERE (EmployeeID, Freq) IN (
    SELECT EmployeeID, MAX(Freq) AS MaxFreq
    FROM (
        SELECT EmployeeID, CompanyName, COUNT(CompanyName) AS Freq
        FROM orders o
        JOIN customers c ON o.CustomerID = c.CustomerID
        GROUP BY EmployeeID, CompanyName
    ) AS tab8
    GROUP BY EmployeeID))AS tab9
    ON e.EmployeeID=tab9.EmployeeID;
    
-- Query 2 Product Variety per employee

SELECT FirstName,LastName,Product_Variety, Most_Sold_Product
FROM employee1 e
JOIN(
	SELECT EmployeeID,COUNT(DISTINCT(ProductName)) AS Product_Variety 
	FROM order_details od 
	JOIN orders o
	ON od.OrderID=o.OrderID
	JOIN products p 
	ON od.ProductID=p.ProductID
	GROUP BY EmployeeID)prods
ON e.EmployeeID=prods.EmployeeID ;

-- Query 3 Employee-Shipper relationship
SELECT FirstName,LastName,CompanyName AS ShippingCompany,ShippingFrequency
FROM employee1 e
JOIN(
	 SELECT EmployeeID,CompanyName, COUNT(CompanyName) AS ShippingFrequency
     FROM orders o JOIN shippers s ON o.ShipVia=s.ShipperID
     GROUP BY EmployeeID,CompanyName
     ORDER BY ShippingFrequency DESC)tab10
     ON e.EmployeeID=tab10.EmployeeID;
	
-- Query 4 Spend on Freights Vs Revenue
SELECT FirstName,LastName,Total_Revenue,Total_Spend_Freights,ROUND((Total_Revenue-Total_Spend_Freights)) AS Margin, ROUND(((Total_Revenue-Total_Spend_Freights)/Total_Revenue),2) AS Margin_Percent 
FROM employee1 e
JOIN(
SELECT EmployeeID, SUM(Freight) AS Total_Spend_Freights FROM orders
GROUP BY EmployeeID)tab12
ON e.EmployeeID=tab12.EmployeeID;
     

SELECT EmployeeID, LastName, ROUND((Total_Revenue/Customers)) AS revenue_per_customer
FROM employee1
ORDER BY revenue_per_customer DESC;

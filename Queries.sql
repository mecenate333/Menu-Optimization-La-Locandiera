-- 1. Which menu dishes have the highest profit margins?

SELECT m.DishName, m.Price AS Revenue, m.Category,
ROUND(SUM(p.Cost * i.Quantity / p.TotalQuantity),2) AS TotalCost,
ROUND(m.Price - SUM(p.Cost * i.Quantity / p.TotalQuantity),2) AS Profit,
ROUND(((m.Price - SUM(p.Cost * i.Quantity / p.TotalQuantity)) / m.Price) * 100,2) AS Profit_Percentage
FROM Menu m
JOIN Ingredients i ON m.DishID = i.DishID
JOIN Products p ON i.IngredientName = p.ProductName
GROUP BY m.DishName, m.Price, m.Category
ORDER BY Profit_Percentage DESC;


-- I was thinking I can get the top 3 for each Category, that could provide a more useful result.

CREATE TEMPORARY TABLE TempMenuProfit AS
SELECT m.DishName, m.Price AS Revenue, m.Category,
ROUND(SUM(p.Cost * i.Quantity / p.TotalQuantity),2) AS TotalCost,
ROUND(m.Price - SUM(p.Cost * i.Quantity / p.TotalQuantity),2) AS Profit,
ROUND(((m.Price - SUM(p.Cost * i.Quantity / p.TotalQuantity)) / m.Price) * 100,2) AS Profit_Percentage
FROM Menu m
JOIN Ingredients i ON m.DishID = i.DishID
JOIN Products p ON i.IngredientName = p.ProductName
GROUP BY m.DishName, m.Price, m.Category
ORDER BY Profit_Percentage DESC;


-- Top 3 dishes by Category
WITH RnkMenu AS (
    SELECT DishName, Category, Profit_Percentage,
ROW_NUMBER() OVER(PARTITION BY Category ORDER BY Profit_Percentage DESC) AS rn
    FROM TempMenuProfit
)
SELECT DishName, Category, Profit_Percentage, rn AS Ranking
FROM RnkMenu
WHERE rn <= 3;

-- Overall, Antipasti dishes have the highest profit margins.
-- It's recommended to promote the Parmegian Asparagus, Eggplant Milanese and Sardinian Mushrooms.


   
-- 2. Which ingredients are used in the most dishes?
SELECT IngredientName, COUNT(*) AS UsageCount
FROM Ingredients
GROUP BY IngredientName
ORDER BY UsageCount DESC;

-- Connected with the previous question we can check the quantity of each Ingredient used
-- The idea would be to precise usage per day to then be easier to calculate month, quarter, year as preferred

SELECT i.IngredientName, round(SUM(i.Quantity * o.Quantity) / count(distinct OrderDate),2) AS TotalUsage, i.Unit AS Unit
FROM Ingredients i
JOIN Orders o ON i.DishID = o.DishID
JOIN Products p ON p.ProductName = i.IngredientName
GROUP BY i.IngredientName, i.Unit
ORDER BY TotalUsage DESC;

-- That allows also to know how much storage is needed (values are express in grams, liters)



-- 3. Which dishes are most frequently ordered?
SELECT m.DishName, count(m.DishName) AS Total
FROM Menu m
JOIN Orders o
ON o.DishID = m.DishID
GROUP BY m.DishName
ORDER BY Total DESC;

-- 4. Which menu items have the highest and lowest sales revenue?

-- I will reuse the temp table TempMenuProfit created for question 1

-- Highest Profit
SELECT DishName, Revenue, Category, Profit
FROM TempMenuProfit
ORDER BY PROFIT DESC
LIMIT 5;

-- Lowest Profit
SELECT DishName, Revenue, Category, Profit
FROM TempMenuProfit
ORDER BY PROFIT ASC
LIMIT 5;


-- The best strategy would be segmented by Category, choosing the top one on each

-- Higher Profit by Category
WITH High_Profit AS (
    SELECT DishName, Revenue, Category, Profit,
ROW_NUMBER() OVER (PARTITION BY Category ORDER BY Profit DESC) AS rn
    FROM TempMenuProfit
)
SELECT DishName, Category, Profit
FROM High_Profit
WHERE rn = 1;

-- Lower Profit by Category
WITH Low_Profit AS (
    SELECT DishName, Revenue, Category, Profit,
ROW_NUMBER() OVER (PARTITION BY Category ORDER BY Profit ASC) AS rn
    FROM TempMenuProfit
)
SELECT DishName, Category, Profit
FROM Low_Profit
WHERE rn = 1 or rn = 2;

-- If we choose more than one we can compare the Category and be sure of the distance between the lower profits
-- Working withe the WHERE clause can be useful to see the adjustment required in the menu (+2)



-- 5. Which Category of dish is most popular among customers?
SELECT m.Category, COUNT(o.OrderID) AS TotalOrders
FROM Menu m
JOIN Orders o ON o.DishID = m.DishID
GROUP BY m.Category
ORDER BY TotalOrders DESC;



-- 6. Which menu items have the highest and lowest quantity sold?

-- Top Selling
SELECT m.DishName, SUM(o.Quantity) AS TotalQuantitySold
FROM Menu m
JOIN Orders o ON o.DishID = m.DishID
GROUP BY m.DishName
ORDER BY TotalQuantitySold DESC
LIMIT 5;

-- Lowest sell
SELECT m.DishName,
IFNULL(SUM(o.Quantity), 0) AS TotalQuantitySold
FROM Menu m
LEFT JOIN Orders o ON o.DishID = m.DishID -- to ensure that all menu items are included in the result set, even the ones never ordered
GROUP BY m.DishName
ORDER BY TotalQuantitySold ASC
LIMIT 5;




-- 7. Which ingredients are very much used and are also the least expensive per unit?
WITH ProductQty AS (
SELECT IngredientName, SUM(Quantity) AS TotalQuantity,
RANK() OVER (ORDER BY SUM(Quantity) DESC) AS QuantityRank
FROM Ingredients
GROUP BY IngredientName
),
ProductCost AS (
SELECT ProductName, Cost,
RANK() OVER (ORDER BY Cost ASC) AS CostRank
FROM Products
GROUP BY ProductName, Cost
)
SELECT
    pq.IngredientName,
    pq.TotalQuantity,
    pc.Cost,
    pq.QuantityRank,
    pc.CostRank AS CostPerUnitRank,
    pq.QuantityRank + pc.CostRank AS CombinedRank
FROM ProductQty pq
JOIN ProductCost pc ON pq.IngredientName = pc.ProductName
ORDER BY CombinedRank;

-- Using two CTE is mainly for replying each of the questions separetaly and the combining to check total score
-- The idea is to increase the usage of those 10-20 products that are more often used


-- 8. Which menu items have the highest and lowest cost of ingredients?

-- Highest
WITH MenuIngredientCost AS (
SELECT m.DishName, m.Category, SUM(p.Cost * i.Quantity) AS TotalIngredientCost
    FROM Menu m
    JOIN Ingredients i ON m.DishID = i.DishID
    JOIN Products p ON i.IngredientName = p.ProductName
    GROUP BY m.DishName, m.Category
)
SELECT MIC.DishName, MIC.Category, MIC.TotalIngredientCost,
RANK() OVER (ORDER BY MIC.TotalIngredientCost DESC) AS "Highest Cost"
FROM MenuIngredientCost MIC
LIMIT 10;

-- Found out that as Secondi Piatti are more expensive dishes, would be smarter segment by Category using a windows function
-- Highest Cost dishes per Category (just the top 3)
WITH MenuIngredientCost AS (
    SELECT m.DishName, m.Category,
    ROUND(SUM(p.Cost * i.Quantity / p.TotalQuantity),2) AS TotalCostPerDish,
ROW_NUMBER() OVER (PARTITION BY m.Category ORDER BY SUM(p.Cost * i.Quantity) DESC) AS RankPerCategory
    FROM Menu m
    JOIN Ingredients i ON m.DishID = i.DishID
    JOIN Products p ON i.IngredientName = p.ProductName
    GROUP BY m.DishName, m.Price, m.Category
)
SELECT MIC.DishName, MIC.Category, MIC.TotalCostPerDish, MIC.RankPerCategory
FROM MenuIngredientCost MIC
WHERE MIC.RankPerCategory <= 3
ORDER BY MIC.Category, MIC.RankPerCategory;

-- Lowest Cost per dish on each Category limited by the top 3 of the list
WITH MenuIngredientCost AS (
    SELECT m.DishName, m.Category,
    ROUND(SUM(p.Cost * i.Quantity / p.TotalQuantity),2) AS TotalCostPerDish,
ROW_NUMBER() OVER (PARTITION BY m.Category ORDER BY SUM(p.Cost * i.Quantity) ASC) AS RankPerCategory
    FROM Menu m
    JOIN Ingredients i ON m.DishID = i.DishID
    JOIN Products p ON i.IngredientName = p.ProductName
    GROUP BY m.DishName, m.Price, m.Category
)
SELECT MIC.DishName, MIC.Category, MIC.TotalCostPerDish, MIC.RankPerCategory
FROM MenuIngredientCost MIC
WHERE MIC.RankPerCategory <= 3
ORDER BY MIC.Category, MIC.RankPerCategory ASC;

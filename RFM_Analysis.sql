SELECT * FROM [Portfolio].[dbo].[sales_data_sample]

SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'sales_data_sample'

-- Select unique values in each column
SELECT DISTINCT status FROM sales_data_sample -- Nice to plot
SELECT DISTINCT year_id FROM sales_data_sample
SELECT DISTINCT PRODUCTLINE FROM sales_data_sample -- Nice to plot
SELECT DISTINCT COUNTRY FROM sales_data_sample -- Nice to plot
SELECT DISTINCT DEALSIZE FROM sales_data_sample -- Nice to plot
SELECT DISTINCT TERRITORY FROM sales_data_sample -- Nice to plot

-- Analysis
-- Grouping Sales by Productline
SELECT PRODUCTLINE, SUM(SALES) Revenue 
FROM sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY 2 desc

-- Grouping Sales by Year
SELECT YEAR_ID, SUM(SALES) Revenue 
FROM sales_data_sample
GROUP BY YEAR_ID
ORDER BY 2 desc

-- See how many months they operate
SELECT DISTINCT Month_ID FROM sales_data_sample WHERE YEAR_ID = 2005

-- Grouping Sales by Dealsize
SELECT DEALSIZE, SUM(SALES) Revenue 
FROM sales_data_sample
GROUP BY DEALSIZE
ORDER BY 2 desc

-- What was the best month for sales in a specific year? How much was earned that month?
SELECT MONTH_ID,SUM(SALES) Revenue, COUNT(ORDERNUMBER) Frequency FROM sales_data_sample
WHERE YEAR_ID = 2004 -- Change the year here
GROUP BY MONTH_ID
ORDER BY 2 DESC

-- November seems to be the best month for sales, but what products do they sell in November.
SELECT MONTH_ID, PRODUCTLINE, sum(SALES) Revenue, COUNT(ORDERNUMBER) Frequency
FROM sales_data_sample
WHERE MONTH_ID = 11 and YEAR_ID = 2004
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC

-- Who is the best customer (RFM Analysis)
-- RFM Consists of 3 factors:
--      Recency: How long ago their purchase was
--      Frequency: How often they purchase
--      Monetary: How much they spent
--      Create temp table
DROP TABLE IF EXISTS #rfm
;WITH rfm AS
(
    SELECT CUSTOMERNAME
            , SUM(SALES) Monetary
            , AVG(SALES) AvgMonetary
            , COUNT(ORDERNUMBER) Frequency
            , MAX(ORDERDATE) last_order_date
            , (select MAX(ORDERDATE) FROM sales_data_sample) max_order_date
            , DATEDIFF(DD, MAX(ORDERDATE), (select MAX(ORDERDATE) FROM sales_data_sample)) Recency
    FROM sales_data_sample
    GROUP BY CUSTOMERNAME
)
, rfm_calc AS
(
    SELECT r.*
        ,NTILE(4) OVER (ORDER BY Recency DESC) rfm_recency
        ,NTILE(4) OVER (ORDER BY Frequency) rfm_frequency
        ,NTILE(4) OVER (ORDER BY Monetary) rfm_monetary
    FROM rfm r
)
SELECT c.*
        , rfm_recency + rfm_frequency + rfm_monetary AS rfm_cell
        , CAST(rfm_recency AS varchar) + CAST(rfm_frequency AS varchar) + CAST(rfm_monetary AS varchar) AS rfm_cell_string
INTO #rfm
FROM rfm_calc c

-- Performing Customer Segmentation
SELECT CUSTOMERNAME, rfm_recency, rfm_frequency, rfm_monetary,
    CASE 
        WHEN rfm_cell_string in (111, 112, 121, 122, 123, 132, 211, 212, 114, 141, 221) THEN 'Lost Customer'
        WHEN rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 234, 144) THEN 'Can not lose'
        WHEN rfm_cell_string in (311, 411, 331, 421, 423, 412) THEN 'New Customer'
        WHEN rfm_cell_string in (222, 223, 233, 322, 232) THEN 'Potential Churners'
        WHEN rfm_cell_string in (323, 333, 321, 422, 332, 432) THEN 'Actives' -- Buy recently and frequently, but at low price
        WHEN rfm_cell_string in (433, 434, 443, 444) THEN 'loyal'
    END rfm_segment
FROM #rfm

-- Finds out what products are most often sell together
SELECT DISTINCT ORDERNUMBER, STUFF(

    (SELECT ',' + PRODUCTCODE
    FROM sales_data_sample p
    WHERE ORDERNUMBER IN
    ( 
            SELECT ORDERNUMBER
            FROM(
                SELECT ORDERNUMBER, COUNT(*) rn
                FROM sales_data_sample
                WHERE [STATUS] = 'Shipped'
                GROUP BY ORDERNUMBER
            ) M
            WHERE rn = 3
        )
        AND p.ORDERNUMBER = s.ORDERNUMBER
    for XML PATH('')), 1,1,'') ProductCodes
FROM sales_data_sample s
ORDER BY 2 DESC
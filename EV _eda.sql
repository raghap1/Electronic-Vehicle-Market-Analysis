
select * from dim_date d 
join electric_vehicle_sales_by_makers em
on d.dates = em.dates
join electric_vehicle_sales_by_state es
on d.dates = es.dates;

-- 1. List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in terms of the number of 2-wheelers sold. 

-- top 3
select em.maker, sum(em.electric_vehicles_sold) as total_vehicles_sold_by_maker 
from electric_vehicle_sales_by_makers em join dim_date d using(dates)
where fiscal_year in (2023, 2024) and vehicle_category like '2%'
group by em.maker
order by 2 desc
limit 3;

-- bottom 3
select em.maker, sum(em.electric_vehicles_sold) as total_vehicles_sold_by_maker 
from electric_vehicle_sales_by_makers em join dim_date d using(dates)
where fiscal_year in (2023, 2024) and vehicle_category like '2%'
group by em.maker
order by 2
limit 3;

-- Identify the top 5 states with the highest penetration rate in 2-wheeler and 4-wheeler EV sales in FY 2024. 
SELECT 
    state, 
    SUM(electric_vehicles_sold) AS total_ev_sales,
    SUM(CASE WHEN vehicle_category = '2-Wheelers' THEN electric_vehicles_sold ELSE 0 END) AS two_wheeler_sales,
    SUM(CASE WHEN vehicle_category = '4-Wheelers' THEN electric_vehicles_sold ELSE 0 END) AS four_wheeler_sales,
    SUM(electric_vehicles_sold) / SUM(total_vehicles_sold) * 100 AS penetration_rate
FROM electric_vehicle_sales_by_state s
JOIN dim_date d ON s.dates = d.dates
WHERE d.fiscal_year = 2024
AND vehicle_category IN ('2-Wheelers', '4-Wheelers')
GROUP BY state
ORDER BY penetration_rate DESC
LIMIT 5;

-- List the states with negative penetration (decline) in EV sales from 2022 to 2024? 

SELECT 
    state, 
    SUM(CASE WHEN fiscal_year = 2022 THEN electric_vehicles_sold ELSE 0 END) AS ev_sales_2022,
    SUM(CASE WHEN fiscal_year = 2024 THEN electric_vehicles_sold ELSE 0 END) AS ev_sales_2024,
sum(electric_vehicles_sold)/sum(total_vehicles_sold) * 100 as penetration_rate
FROM electric_vehicle_sales_by_state evss
JOIN dim_date dd ON evss.dates = dd.dates
where fiscal_year between 2022 and 2024
GROUP BY state;

-- What are the quarterly trends based on sales volume for the top 5 EV makers (4-wheelers) from 2022 to 2024?

with cte as (
select d.quarter,em.maker, sum(em.electric_vehicles_sold) as sales_volume
from electric_vehicle_sales_by_makers em
join dim_date d using(dates)
where em.vehicle_category like ("4%") and d.fiscal_year between 2022 and 2024
group by 1,2
order by 3 desc
) 
select quarter, maker, sales_volume from
(select *
, rank() over(partition by quarter order by sales_volume desc) as rk
 from cte) ranked_cte
 where rk < 6;

-- How do the EV sales and penetration rates in Delhi compare to Karnataka for 2024? 

(select state, sum(es.electric_vehicles_sold) as ev_sales_delhi, (sum(es.electric_vehicles_sold)/sum(es.total_vehicles_sold) * 100) as penetration_rate_delhi from electric_vehicle_sales_by_state es
join dim_date d using(dates)
where state = "Delhi" and fiscal_year = 2024
group by state)
union all
(select state, sum(es.electric_vehicles_sold) as ev_sales, (sum(es.electric_vehicles_sold)/sum(es.total_vehicles_sold) * 100) as penetration_rate from electric_vehicle_sales_by_state es
join dim_date d using(dates)
where state = "Karnataka" and fiscal_year = 2024
group by state);

-- List down the compounded annual growth rate (CAGR) in 4-wheeler units for the top 5 makers from 2022 to 2024.


with cte as (
select em.maker,em.vehicle_category,
 SUM(CASE WHEN d.fiscal_year = 2022 THEN em.electric_vehicles_sold ELSE 0 END) AS sales_2022,
SUM(CASE WHEN d.fiscal_year = 2024 THEN em.electric_vehicles_sold ELSE 0 END) AS sales_2024
 from electric_vehicle_sales_by_makers em
join dim_date d using(dates)
where em.vehicle_category like "4%" and d.fiscal_year between 2022 and 2024
group by 1,2)
select maker,vehicle_category, -- CAGR = [(Ending Value / Beginning Value) ** 1/n] -1
round((pow(sales_2024/sales_2022,1/2)-1) * 100,0) as cagr
 from cte
 order by 3 desc
 limit 5;

-- List down the top 10 states that had the highest compounded annual growth rate (CAGR) from 2022 to 2024 in total vehicles sold. 

with cte as (
select es.state,
 SUM(CASE WHEN d.fiscal_year = 2022 THEN es.electric_vehicles_sold ELSE 0 END) AS sales_2022,
SUM(CASE WHEN d.fiscal_year = 2024 THEN es.electric_vehicles_sold  ELSE 0 END) AS sales_2024
 from electric_vehicle_sales_by_state es
join dim_date d using(dates)
where d.fiscal_year between 2022 and 2024
group by 1)
select state,sales_2022,sales_2024, -- CAGR = [(Ending Value / Beginning Value) ** 1/n] -1
round((pow(sales_2024/sales_2022,1/2)-1) * 100,0) as cagr
 from cte
 order by 4 desc
limit 10;

-- What are the peak and low season months for EV sales based on the data from 2022 to 2024? 

select DATE_FORMAT(d.dates, '%Y-%m') AS month, sum(em.electric_vehicles_sold) as EV_sales from dim_date d 
join electric_vehicle_sales_by_makers em using(dates)
where d.fiscal_year between 2022 and 2024
group by 1
order by 2 desc;

-- What is the projected number of EV sales (including 2-wheelers and 4 wheelers) for the top 10 states by penetration rate in 2030, based on the compounded annual growth rate (CAGR) from previous years? 

-- Step 1: Calculate penetration rate and rank the top 10 states by EV penetration rate
WITH state_sales AS (
    SELECT 
        ev.state,
        SUM(CASE WHEN dd.fiscal_year = 2022 THEN ev.electric_vehicles_sold ELSE 0 END) AS sales_2022,
        SUM(CASE WHEN dd.fiscal_year = 2024 THEN ev.electric_vehicles_sold ELSE 0 END) AS sales_2024,
        SUM(CASE WHEN dd.fiscal_year = 2024 THEN ev.total_vehicles_sold ELSE 0 END) AS total_vehicles_2024
    FROM electric_vehicle_sales_by_state ev
    JOIN dim_date dd ON ev.dates = dd.dates
    WHERE dd.fiscal_year between 2022 and 2024
    GROUP BY ev.state
),

penetration_rate AS (
    -- Calculate penetration rate for 2024
    SELECT 
        state,
        (sales_2024 / total_vehicles_2024) * 100 AS penetration_rate_2024
    FROM state_sales
    WHERE total_vehicles_2024 > 0
),

top_10_states AS (
    -- Rank the states by penetration rate and select the top 10
    SELECT 
        state
    FROM penetration_rate
    ORDER BY penetration_rate_2024 DESC
    LIMIT 10
),

cagr_data AS (
    -- Step 2: Calculate CAGR for EV sales from 2022 to 2024
    SELECT 
        s.state,
        s.sales_2022,
        s.sales_2024,
        ROUND((POW((s.sales_2024 / s.sales_2022), 1/2.0) - 1), 4) AS cagr
    FROM state_sales s
    JOIN top_10_states t ON s.state = t.state
    WHERE s.sales_2022 > 0
)

-- Step 3: Project EV sales for 2030
SELECT 
    c.state,
    c.sales_2024 AS sales_in_2024,
    ROUND(c.sales_2024 * POW((1 + c.cagr), (2030 - 2024)), 0) AS projected_sales_in_2030,
    ROUND(c.cagr * 100, 2) AS cagr_percentage
FROM cagr_data c
ORDER BY projected_sales_in_2030 DESC;

-- Estimate the revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2022 vs 2024 and 2023 vs 2024, assuming an average unit price. H
with yearly_sales as (
select
sum(case when em.vehicle_category like "4%" and d.fiscal_year = 2024 then em.electric_vehicles_sold else 0 end) as sales_2024_4w
,sum(case when em.vehicle_category like "2%" and d.fiscal_year = 2024 then em.electric_vehicles_sold else 0 end) as sales_2024_2w
,sum(case when em.vehicle_category like "4%" and d.fiscal_year = 2023 then em.electric_vehicles_sold else 0 end) as sales_2023_4w
,sum(case when em.vehicle_category like "2%" and d.fiscal_year = 2023 then em.electric_vehicles_sold else 0 end) as sales_2023_2w
,sum(case when em.vehicle_category like "4%" and d.fiscal_year = 2022 then em.electric_vehicles_sold else 0 end) as sales_2022_4w
,sum(case when em.vehicle_category like "2%" and d.fiscal_year = 2022 then em.electric_vehicles_sold else 0 end) as sales_2022_2w
from dim_date d join electric_vehicle_sales_by_makers em using(dates)
),
revenue_yearly_sales as (
select sales_2024_4w * 1500000 as revenue_24_4w, sales_2024_2w * 85000 as revenue_24_2w 
, sales_2023_4w * 1500000 as revenue_23_4w, sales_2023_2w * 85000 as revenue_23_2w 
, sales_2022_4w * 1500000 as revenue_22_4w, sales_2022_2w * 85000 as revenue_22_2w 
from yearly_sales
)
select ((revenue_24_4w-revenue_22_4w)/revenue_22_4w) * 100 as revenue_growth_rate_22vs24_4w
, ((revenue_24_2w-revenue_22_2w)/revenue_22_2w) * 100 as revenue_growth_rate_22vs24_2w
,((revenue_24_4w-revenue_23_4w)/revenue_23_4w) * 100 as revenue_growth_rate_23vs24_4w
,((revenue_24_2w-revenue_23_2w)/revenue_23_2w) * 100 as revenue_growth_rate_23vs24_2w
from revenue_yearly_sales




















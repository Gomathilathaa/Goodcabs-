#City Level Fare and Trip Summary Report:

Select city_name,
	count(trip_id) as total_trips, 
	round(sum(t.fare_amount)/sum(t.distance_travelled_km),2) as avg_fare_per_km,
    avg(t.fare_amount) as avg_fare_per_trip,
    round((count(t.trip_id) / (select count(*) from fact_trips) * 100), 2) as pct_contribution_to_totaltrips
from fact_trips t
join dim_city c
on c.city_id = t.city_id
Group by city_name
order by total_trips desc
;

#Monthly City level Trips target Performance Report
WITH cte AS (
    SELECT 
        c.city_id, 
        c.city_name,
        d.month_name AS month,
        COUNT(t.trip_id) AS actual_trips,
        MAX(mtt.total_target_trips) AS target_trips  -- Aggregate target_trips
    FROM 
        fact_trips t
    JOIN 
        dim_city c ON c.city_id = t.city_id
    JOIN 
        dim_date d ON d.date = t.date
    JOIN 
        targets_db.monthly_target_trips mtt ON t.city_id = mtt.city_id AND d.start_of_month = mtt.month
    GROUP BY 
        c.city_id, c.city_name, d.month_name
)
SELECT 
    city_id,
    city_name,
    month,
    actual_trips,
    target_trips,
    CASE 
        WHEN actual_trips >= target_trips THEN 'Above Target'
        WHEN actual_trips < target_trips THEN 'Below Target'
    END AS performance_target,
    ROUND((actual_trips / target_trips) * 100, 2) AS pct_difference  -- Express as a percentage
FROM 
    cte;

#City-Level repeat Passenger Trip Frequency Report
WITH repeat_trip_distribution AS (
    SELECT 
        c.city_id,
        c.city_name,
        r.trip_count,  -- Number of trips taken by repeat passengers (e.g., 2 trips, 3 trips, etc.)
        r.repeat_passenger_count
    FROM 
        dim_repeat_trip_distribution r
    JOIN 
        dim_city c ON r.city_id = c.city_id
)
SELECT 
    r.city_name,
    ROUND(SUM(CASE WHEN r.trip_count = 2 THEN r.repeat_passenger_count ELSE 0 END) / SUM(r.repeat_passenger_count) * 100, 2) AS pct_2_trips,
    ROUND(SUM(CASE WHEN r.trip_count = 3 THEN r.repeat_passenger_count ELSE 0 END) / SUM(r.repeat_passenger_count) * 100, 2) AS pct_3_trips,
    ROUND(SUM(CASE WHEN r.trip_count = 4 THEN r.repeat_passenger_count ELSE 0 END) / SUM(r.repeat_passenger_count) * 100, 2) AS pct_4_trips,
    ROUND(SUM(CASE WHEN r.trip_count = 5 THEN r.repeat_passenger_count ELSE 0 END) / SUM(r.repeat_passenger_count) * 100, 2) AS pct_5_trips,
    ROUND(SUM(CASE WHEN r.trip_count = 6 THEN r.repeat_passenger_count ELSE 0 END) / SUM(r.repeat_passenger_count) * 100, 2) AS pct_6_trips,
    ROUND(SUM(CASE WHEN r.trip_count = 7 THEN r.repeat_passenger_count ELSE 0 END) / SUM(r.repeat_passenger_count) * 100, 2) AS pct_7_trips,
    ROUND(SUM(CASE WHEN r.trip_count = 8 THEN r.repeat_passenger_count ELSE 0 END) / SUM(r.repeat_passenger_count) * 100, 2) AS pct_8_trips,
    ROUND(SUM(CASE WHEN r.trip_count = 9 THEN r.repeat_passenger_count ELSE 0 END) / SUM(r.repeat_passenger_count) * 100, 2) AS pct_9_trips,
    ROUND(SUM(CASE WHEN r.trip_count = 10 THEN r.repeat_passenger_count ELSE 0 END) / SUM(r.repeat_passenger_count) * 100, 2) AS pct_10_trips
FROM 
    repeat_trip_distribution r
GROUP BY 
    r.city_name
ORDER BY 
    r.city_name;
    
    
    
#Identify cities with highest and lowest total new passengers
WITH cte1 AS (
    SELECT 
        c.city_name, 
        SUM(ps.new_passengers) AS total_new_passengers,	
        RANK() OVER (ORDER BY SUM(ps.new_passengers) DESC) AS highest_rank
    FROM 
        fact_passenger_summary ps
    JOIN 
        dim_city c ON c.city_id = ps.city_id
    GROUP BY 
        c.city_name
)
SELECT 
    city_name, 
    total_new_passengers, 
    highest_rank,
    CASE 
        WHEN highest_rank <= 3 THEN 'Top 3'
        WHEN highest_rank > (SELECT MAX(highest_rank) FROM cte1) - 3 THEN 'Bottom 3'
        ELSE 'Other'
    END AS category
FROM 
    cte1
ORDER BY 
    highest_rank;
    
#Identify month with highest revenue for each city
WITH monthly_revenue AS (
    SELECT 
        c.city_name,
        d.month_name,
        SUM(t.fare_amount) AS total_revenue,
        round((max(t.fare_amount)/sum(t.fare_amount))*100,2) as pct_contribution
    FROM 
        fact_trips t
    JOIN 
        dim_city c ON c.city_id = t.city_id
    JOIN 
        dim_date d ON d.date = t.date
    GROUP BY 
        c.city_name, d.month_name
),
highest_revenue_month AS (
    SELECT 
        city_name,
        month_name,
        total_revenue,
        RANK() OVER (PARTITION BY city_name ORDER BY total_revenue DESC) AS revenue_rank,pct_contribution
    FROM 
        monthly_revenue
)
SELECT 
    city_name,
    month_name AS highest_revenue_month,  
    total_revenue AS revenue,
    pct_contribution as pct
FROM 
    highest_revenue_month
WHERE 
    revenue_rank = 1
ORDER BY 
    city_name;

#Repeat Passenger Rate Analysis:
SELECT  
    c.city_name,
    ps.month,
    ps.total_passengers,
    ps.repeat_passengers,
    -- Monthly Repeat Passenger Rate (per city per month)
    CASE 
        WHEN ps.total_passengers > 0 THEN (ps.repeat_passengers / ps.total_passengers) * 100
        ELSE 0
    END AS monthly_repeat_passenger_rate,
    -- City-wide Repeat Passenger Rate (aggregated across all months for each city)
    city_repeat_rate.city_repeat_passenger_rate
FROM fact_passenger_summary ps
JOIN dim_city c ON c.city_id = ps.city_id
-- Subquery to calculate the city-wide repeat passenger rate
JOIN (
    SELECT 
        c.city_name,
        SUM(ps.repeat_passengers) AS total_repeat_passengers,
        SUM(ps.total_passengers) AS total_passengers_across_months,
        CASE 
            WHEN SUM(ps.total_passengers) > 0 THEN (SUM(ps.repeat_passengers) / SUM(ps.total_passengers)) * 100
            ELSE 0
        END AS city_repeat_passenger_rate
    FROM fact_passenger_summary ps
    JOIN dim_city c ON c.city_id = ps.city_id
    GROUP BY c.city_name
) city_repeat_rate 
ON city_repeat_rate.city_name = c.city_name
ORDER BY c.city_name, ps.month;



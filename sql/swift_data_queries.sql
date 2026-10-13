-- =====================================================================
-- Swift Data Logistics DBMS
-- File: swift_data_queries.sql
-- Description: The 7 analytical DBMS queries demonstrating advanced SQL:
--              Joins, Aggregations, GROUP BY, HAVING, Subqueries,
--              Conditional sums, and Business Intelligence analytics.
-- =====================================================================

USE swift_data;

-- ---------------------------------------------------------------------
-- Q1. Full Tracking History of One Parcel (TRK1002)
-- Demonstrates: INNER JOIN, LEFT JOIN, WHERE filter, ORDER BY timeline
-- Rationale: LEFT JOIN on Hub preserves events where hub_id is NULL.
-- ---------------------------------------------------------------------
SELECT 
    s.tracking_number,
    te.event_time,
    te.status,
    IFNULL(h.name, 'Field / In Transit') AS hub_location,
    te.remarks
FROM Tracking_Event te
JOIN Shipment s ON s.shipment_id = te.shipment_id
LEFT JOIN Hub h ON h.hub_id = te.hub_id
WHERE s.tracking_number = 'TRK1002'
ORDER BY te.event_time ASC, te.event_id ASC;


-- ---------------------------------------------------------------------
-- Q2. Deliveries Completed Per Driver
-- Demonstrates: Multi-table JOINs, GROUP BY, COUNT(DISTINCT ...), Aggregation
-- Rationale: Evaluates driver efficiency across assigned trips.
-- ---------------------------------------------------------------------
SELECT 
    d.driver_id,
    d.name AS driver_name,
    COUNT(DISTINCT t.trip_id) AS total_trips,
    COUNT(DISTINCT CASE WHEN s.current_status = 'Delivered' THEN s.shipment_id END) AS shipments_delivered
FROM Driver d
LEFT JOIN Trip t ON t.driver_id = d.driver_id
LEFT JOIN Trip_Shipment ts ON ts.trip_id = t.trip_id
LEFT JOIN Shipment s ON s.shipment_id = ts.shipment_id
GROUP BY d.driver_id, d.name
ORDER BY shipments_delivered DESC, total_trips DESC;


-- ---------------------------------------------------------------------
-- Q3. On-Time vs Late Delivery Analysis Per Destination Hub
-- Demonstrates: Boolean conditional expression inside SUM(), Percentage calculation
-- Rationale: DATE(s.delivered_date) > s.expected_date evaluates to 1 or 0 in MySQL.
-- ---------------------------------------------------------------------
SELECT 
    h.hub_id,
    h.name AS destination_hub,
    h.city,
    COUNT(*) AS total_delivered,
    SUM(DATE(s.delivered_date) > s.expected_date) AS late_deliveries,
    ROUND(100.0 * SUM(DATE(s.delivered_date) > s.expected_date) / COUNT(*), 1) AS late_delivery_pct
FROM Shipment s
JOIN Hub h ON h.hub_id = s.dest_hub_id
WHERE s.current_status = 'Delivered'
GROUP BY h.hub_id, h.name, h.city
ORDER BY late_deliveries DESC, total_delivered DESC;


-- ---------------------------------------------------------------------
-- Q4. Fleet Vehicle Capacity Utilization
-- Demonstrates: Mathematical computation on columns, Sorting by utilization ratio
-- Rationale: Identifies underutilized vs overloaded vehicles across hubs.
-- ---------------------------------------------------------------------
SELECT 
    v.plate_no,
    v.type AS vehicle_type,
    v.status,
    h.name AS home_hub,
    v.current_load_kg,
    v.capacity_kg,
    ROUND(100.0 * v.current_load_kg / v.capacity_kg, 1) AS utilization_percent
FROM Vehicle v
JOIN Hub h ON h.hub_id = v.hub_id
ORDER BY utilization_percent DESC;


-- ---------------------------------------------------------------------
-- Q5. Revenue and Volume Breakdown
-- Part A: By Service Type (Standard vs Express)
-- Part B: By Origin Hub City
-- Demonstrates: GROUP BY, SUM, COUNT, Revenue aggregation
-- ---------------------------------------------------------------------
-- Part A: By Service Type
SELECT 
    service_type,
    COUNT(*) AS total_shipments,
    SUM(cost) AS total_revenue,
    ROUND(AVG(cost), 2) AS avg_revenue_per_shipment
FROM Shipment
GROUP BY service_type
ORDER BY total_revenue DESC;

-- Part B: By Source City
SELECT 
    h.city AS origin_city,
    COUNT(*) AS total_booked,
    SUM(s.cost) AS total_revenue
FROM Shipment s
JOIN Hub h ON h.hub_id = s.source_hub_id
GROUP BY h.city
ORDER BY total_revenue DESC;


-- ---------------------------------------------------------------------
-- Q6. Customers With Failed Deliveries
-- Demonstrates: GROUP BY with multi-column projection, JOIN on Sender
-- Rationale: Flags customer addresses or senders experiencing recurrent exceptions.
-- ---------------------------------------------------------------------
SELECT 
    c.customer_id,
    c.name AS customer_name,
    c.city,
    c.phone,
    COUNT(*) AS failed_shipment_count
FROM Shipment s
JOIN Customer c ON c.customer_id = s.sender_id
WHERE s.current_status = 'Failed'
GROUP BY c.customer_id, c.name, c.city, c.phone
ORDER BY failed_shipment_count DESC;


-- ---------------------------------------------------------------------
-- Q7. Multi-Leg Shipments (Shipments Travelling On More Than One Trip)
-- Demonstrates: GROUP BY with HAVING clause on aggregated count
-- Rationale: Proves the many-to-many relationship resolved by Trip_Shipment.
-- ---------------------------------------------------------------------
SELECT 
    s.shipment_id,
    s.tracking_number,
    s.weight_kg,
    s.current_status,
    COUNT(ts.trip_id) AS trips_used
FROM Shipment s
JOIN Trip_Shipment ts ON ts.shipment_id = s.shipment_id
GROUP BY s.shipment_id, s.tracking_number, s.weight_kg, s.current_status
HAVING COUNT(ts.trip_id) > 1;

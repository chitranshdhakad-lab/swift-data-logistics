-- =====================================================================
-- Swift Data Logistics DBMS
-- File: swift_data_sample.sql
-- Description: Realistic sample dataset:
--              5 Hubs, 12 Customers, 8 Drivers, 8 Vehicles,
--              15 Shipments, 14 Trips, 14 Trip Links, 75 Tracking Events.
-- =====================================================================

USE swift_data;

-- Disable foreign key checks for clean loading
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE Tracking_Event;
TRUNCATE TABLE Trip_Shipment;
TRUNCATE TABLE Trip;
TRUNCATE TABLE Shipment;
TRUNCATE TABLE Vehicle;
TRUNCATE TABLE Driver;
TRUNCATE TABLE Customer;
TRUNCATE TABLE Hub;

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1. Insert Hubs (5 Hubs across Central, West, and North India)
-- ---------------------------------------------------------------------
INSERT INTO Hub (hub_id, name, city, capacity) VALUES
(1, 'Bhopal Central Hub', 'Bhopal', 5000),
(2, 'Indore Main Hub', 'Indore', 4500),
(3, 'Delhi North Hub', 'Delhi', 8000),
(4, 'Mumbai West Hub', 'Mumbai', 10000),
(5, 'Nagpur Central Hub', 'Nagpur', 4000);

-- ---------------------------------------------------------------------
-- 2. Insert Customers (12 Customers)
-- ---------------------------------------------------------------------
INSERT INTO Customer (customer_id, name, phone, email, address, city, pincode) VALUES
(1, 'Rohit Mehta', '9826011111', 'rohit.mehta@example.com', '12 M.P. Nagar Zone 1', 'Bhopal', '462011'),
(2, 'Amit Patil', '9826022222', 'amit.patil@example.com', '45 Palasia Main Road', 'Indore', '452001'),
(3, 'Priya Sharma', '9811033333', 'priya.sharma@example.com', 'B-42 Connaught Place', 'Delhi', '110001'),
(4, 'Rajesh Verma', '9820044444', 'rajesh.verma@example.com', '88 Bandra West', 'Mumbai', '400050'),
(5, 'Sunita Joshi', '9712055555', 'sunita.joshi@example.com', '10 Ramdaspeth', 'Nagpur', '440010'),
(6, 'Deepak Tiwari', '9826066666', 'deepak.t@example.com', 'Arera Colony E-3', 'Bhopal', '462016'),
(7, 'Neha Singh', '9826077777', 'neha.singh@example.com', 'Vijay Nagar Scheme 54', 'Indore', '452010'),
(8, 'Vikram Malhotra', '9811088888', 'vikram.m@example.com', 'Hauz Khas Enclave', 'Delhi', '110016'),
(9, 'Ananya Deshmukh', '9820099999', 'ananya.d@example.com', 'Andheri East Link Road', 'Mumbai', '400069'),
(10, 'Manish Jain', '9712010101', 'manish.jain@example.com', 'Civil Lines Ward 12', 'Nagpur', '440001'),
(11, 'Kavita Nair', '9826012121', 'kavita.n@example.com', 'Shahpura Sector A', 'Bhopal', '462039'),
(12, 'Suresh Gupta', '9811013131', 'suresh.g@example.com', 'Karol Bagh Market', 'Delhi', '110005');

-- ---------------------------------------------------------------------
-- 3. Insert Drivers (8 Drivers)
-- ---------------------------------------------------------------------
INSERT INTO Driver (driver_id, name, phone, license_no, hub_id, status) VALUES
(1, 'Ramesh Yadav', '9901122331', 'DL-0420180011', 1, 'Active'),
(2, 'Suresh Solanki', '9901122332', 'DL-0420180012', 1, 'Active'),
(3, 'Vijay Chouhan', '9901122333', 'DL-0420180013', 2, 'Active'),
(4, 'Manoj Rathore', '9901122334', 'DL-0420180014', 2, 'Active'),
(5, 'Harpreet Singh', '9901122335', 'DL-0420180015', 3, 'Active'),
(6, 'Satish Pandey', '9901122336', 'DL-0420180016', 3, 'Active'),
(7, 'Ganesh Shinde', '9901122337', 'DL-0420180017', 4, 'Active'),
(8, 'Nitin Raut', '9901122338', 'DL-0420180018', 5, 'Active');

-- ---------------------------------------------------------------------
-- 4. Insert Vehicles (8 Vehicles)
-- ---------------------------------------------------------------------
INSERT INTO Vehicle (vehicle_id, plate_no, type, capacity_kg, current_load_kg, hub_id, status) VALUES
(1, 'MP04-BK-1001', 'Bike', 30.00, 0.00, 1, 'Available'),
(2, 'MP04-VN-2001', 'Van', 500.00, 45.00, 1, 'On Trip'),
(3, 'MP04-TR-3001', 'Truck', 3500.00, 120.00, 1, 'On Trip'),
(4, 'MP09-VN-2002', 'Van', 600.00, 0.00, 2, 'Available'),
(5, 'MP09-TR-3002', 'Truck', 4000.00, 35.00, 2, 'On Trip'),
(6, 'DL01-TR-3003', 'Truck', 4500.00, 0.00, 3, 'Available'),
(7, 'MH02-TR-3004', 'Truck', 5000.00, 0.00, 4, 'Available'),
(8, 'MH31-VN-2003', 'Van', 550.00, 0.00, 5, 'Available');

-- ---------------------------------------------------------------------
-- 5. Insert Shipments (15 Shipments: TRK1001 to TRK1015)
-- Pricing: Standard = 80 + 25*kg (+50 fragile); Express = 150 + 40*kg (+50 fragile)
-- ---------------------------------------------------------------------
INSERT INTO Shipment (shipment_id, tracking_number, sender_id, receiver_id, source_hub_id, dest_hub_id, weight_kg, is_fragile, service_type, booking_date, expected_date, delivered_date, current_status, cost) VALUES
(1, 'TRK1001', 1, 2, 1, 2, 4.00, FALSE, 'Standard', '2026-09-01 09:00:00', '2026-09-05', '2026-09-04 16:30:00', 'Delivered', 180.00),
(2, 'TRK1002', 6, 4, 1, 4, 8.50, TRUE,  'Standard', '2026-09-02 10:15:00', '2026-09-06', '2026-09-05 14:20:00', 'Delivered', 342.50),
(3, 'TRK1003', 2, 3, 2, 3, 12.00, FALSE, 'Standard', '2026-09-03 11:30:00', '2026-09-07', '2026-09-09 11:00:00', 'Delivered', 380.00),
(4, 'TRK1004', 3, 4, 3, 4, 2.50, FALSE, 'Express',  '2026-09-04 14:00:00', '2026-09-06', '2026-09-06 17:45:00', 'Delivered', 250.00),
(5, 'TRK1005', 4, 1, 4, 1, 6.00, FALSE, 'Standard', '2026-09-05 08:45:00', '2026-09-09', '2026-09-08 12:10:00', 'Delivered', 230.00),
(6, 'TRK1006', 7, 5, 2, 5, 15.00, TRUE,  'Standard', '2026-09-06 13:00:00', '2026-09-10', NULL,                 'In Transit', 505.00),
(7, 'TRK1007', 8, 2, 3, 2, 3.20, FALSE, 'Express',  '2026-09-07 10:00:00', '2026-09-09', '2026-09-09 15:30:00', 'Delivered', 278.00),
(8, 'TRK1008', 5, 9, 5, 4, 9.00, FALSE, 'Standard', '2026-09-08 16:30:00', '2026-09-12', '2026-09-11 18:00:00', 'Delivered', 305.00),
(9, 'TRK1009', 1, 4, 1, 4, 20.00, FALSE, 'Standard', '2026-09-09 11:15:00', '2026-09-13', NULL,                 'In Transit', 580.00),
(10, 'TRK1010', 9, 3, 4, 3, 5.00, TRUE,  'Express',  '2026-09-10 09:30:00', '2026-09-12', '2026-09-13 10:15:00', 'Delivered', 400.00),
(11, 'TRK1011', 11, 5, 1, 5, 7.50, FALSE, 'Express',  '2026-09-11 15:00:00', '2026-09-13', NULL,                 'In Transit', 450.00),
(12, 'TRK1012', 12, 1, 3, 1, 10.00, FALSE, 'Standard', '2026-09-12 12:00:00', '2026-09-16', NULL,                 'Booked',     330.00),
(13, 'TRK1013', 10, 2, 5, 2, 14.00, FALSE, 'Express',  '2026-09-13 14:15:00', '2026-09-15', NULL,                 'Out for Delivery', 710.00),
(14, 'TRK1014', 1, 8, 1, 3, 18.00, TRUE,  'Standard', '2026-09-14 10:30:00', '2026-09-18', NULL,                 'Failed',     580.00),
(15, 'TRK1015', 2, 9, 2, 4, 8.00, FALSE, 'Express',  '2026-09-15 11:45:00', '2026-09-17', NULL,                 'Failed',     470.00);

-- ---------------------------------------------------------------------
-- 6. Insert Trips (14 Trips)
-- ---------------------------------------------------------------------
INSERT INTO Trip (trip_id, driver_id, vehicle_id, from_hub_id, to_hub_id, start_time, end_time, status) VALUES
(1,  1, 2, 1, 2, '2026-09-01 10:00:00', '2026-09-01 16:00:00', 'Completed'),
(2,  3, 4, 2, 1, '2026-09-02 08:30:00', '2026-09-02 14:00:00', 'Completed'),
(3,  5, 6, 3, 4, '2026-09-02 11:00:00', '2026-09-03 07:00:00', 'Completed'),
(4,  7, 7, 4, 1, '2026-09-04 09:00:00', '2026-09-05 06:00:00', 'Completed'),
(5,  2, 3, 1, 4, '2026-09-04 12:00:00', '2026-09-05 08:00:00', 'Completed'),
(6,  4, 5, 2, 3, '2026-09-05 14:00:00', '2026-09-06 09:00:00', 'Completed'),
(7,  1, 3, 1, 2, '2026-09-09 13:00:00', '2026-09-09 18:30:00', 'Completed'), -- Trip 7 (TRK1009 leg 1)
(8,  8, 8, 5, 4, '2026-09-09 08:00:00', '2026-09-10 04:00:00', 'Completed'),
(9,  6, 6, 3, 2, '2026-09-10 10:00:00', '2026-09-11 05:00:00', 'Completed'),
(10, 7, 7, 4, 3, '2026-09-11 11:30:00', '2026-09-12 08:00:00', 'Completed'),
(11, 4, 5, 2, 4, '2026-09-11 13:00:00', NULL,                 'Ongoing'),   -- Trip 11 (TRK1009 leg 2)
(12, 2, 3, 1, 5, '2026-09-12 10:00:00', NULL,                 'Planned'),   -- Trip 12 (Planned)
(13, 8, 8, 5, 2, '2026-09-13 15:00:00', NULL,                 'Ongoing'),
(14, 1, 2, 1, 3, '2026-09-14 11:00:00', NULL,                 'Ongoing');

-- ---------------------------------------------------------------------
-- 7. Insert Trip_Shipment (14 Links)
-- Note: TRK1009 travels on both Trip 7 and Trip 11 (demonstrates M:N)
-- ---------------------------------------------------------------------
INSERT INTO Trip_Shipment (trip_id, shipment_id, loaded_at) VALUES
(1,  1,  '2026-09-01 09:45:00'),
(5,  2,  '2026-09-04 11:30:00'),
(6,  3,  '2026-09-05 13:30:00'),
(3,  4,  '2026-09-02 10:30:00'),
(4,  5,  '2026-09-04 08:30:00'),
(2,  6,  '2026-09-06 14:00:00'),
(9,  7,  '2026-09-10 09:30:00'),
(8,  8,  '2026-09-09 07:30:00'),
(7,  9,  '2026-09-09 12:30:00'), -- TRK1009 on Trip 7 (Bhopal -> Indore)
(11, 9,  '2026-09-11 12:30:00'), -- TRK1009 on Trip 11 (Indore -> Mumbai)
(10, 10, '2026-09-11 11:00:00'),
(7,  11, '2026-09-09 12:45:00'),
(13, 13, '2026-09-13 14:45:00'),
(14, 14, '2026-09-14 10:45:00');

-- ---------------------------------------------------------------------
-- 8. Insert Tracking_Events (75 events covering full lifecycles)
-- ---------------------------------------------------------------------
INSERT INTO Tracking_Event (shipment_id, hub_id, status, remarks, event_time) VALUES
-- TRK1001 (id 1)
(1, 1, 'Booked', 'Parcel received from sender', '2026-09-01 09:00:00'),
(1, 1, 'Picked Up', 'Dispatched to sorting deck', '2026-09-01 09:30:00'),
(1, 1, 'Departed Hub', 'On board vehicle for Indore', '2026-09-01 10:00:00'),
(1, 2, 'Arrived at Hub', 'Received at Indore Main Hub', '2026-09-01 16:30:00'),
(1, 2, 'Out for Delivery', 'Courier out for customer delivery', '2026-09-04 10:00:00'),
(1, 2, 'Delivered', 'Delivered and signed by Amit Patil', '2026-09-04 16:30:00'),

-- TRK1002 (id 2) - Detailed timeline for Viva Q1
(2, 1, 'Booked', 'Shipment booked online at Bhopal Central', '2026-09-02 10:15:00'),
(2, 1, 'Picked Up', 'Packed with Fragile safety packaging', '2026-09-02 11:00:00'),
(2, 1, 'Arrived at Hub', 'Moved to long-haul staging', '2026-09-02 14:00:00'),
(2, 1, 'Departed Hub', 'Loaded onto interstate truck MP04-TR-3001', '2026-09-04 12:00:00'),
(2, 4, 'Arrived at Hub', 'Arrived at Mumbai West Hub', '2026-09-05 08:30:00'),
(2, 4, 'Out for Delivery', 'With local delivery executive', '2026-09-05 10:30:00'),
(2, 4, 'Delivered', 'Delivered safely to Rajesh Verma', '2026-09-05 14:20:00'),

-- TRK1003 (id 3) - Delivered late to Delhi
(3, 2, 'Booked', 'Booked at Indore', '2026-09-03 11:30:00'),
(3, 2, 'Departed Hub', 'Departed for Delhi', '2026-09-05 14:00:00'),
(3, 3, 'Arrived at Hub', 'Arrived at Delhi North', '2026-09-06 10:00:00'),
(3, 3, 'Out for Delivery', 'Out for delivery', '2026-09-09 09:00:00'),
(3, 3, 'Delivered', 'Delivered past expected date', '2026-09-09 11:00:00'),

-- TRK1004 (id 4)
(4, 3, 'Booked', 'Express parcel booked', '2026-09-04 14:00:00'),
(4, 3, 'Departed Hub', 'Direct transit to Mumbai', '2026-09-04 15:00:00'),
(4, 4, 'Arrived at Hub', 'Arrived Mumbai Hub', '2026-09-06 09:00:00'),
(4, 4, 'Out for Delivery', 'Priority courier out', '2026-09-06 14:00:00'),
(4, 4, 'Delivered', 'Delivered on time', '2026-09-06 17:45:00'),

-- TRK1005 (id 5)
(5, 4, 'Booked', 'Booked in Mumbai', '2026-09-05 08:45:00'),
(5, 4, 'Departed Hub', 'Departed for Bhopal', '2026-09-05 10:00:00'),
(5, 1, 'Arrived at Hub', 'Arrived at Bhopal', '2026-09-08 07:00:00'),
(5, 1, 'Out for Delivery', 'Out for delivery', '2026-09-08 09:30:00'),
(5, 1, 'Delivered', 'Delivered to Rohit Mehta', '2026-09-08 12:10:00'),

-- TRK1006 (id 6) - In Transit
(6, 2, 'Booked', 'Booked at Indore Main', '2026-09-06 13:00:00'),
(6, 2, 'Picked Up', 'Picked up from sender', '2026-09-06 13:45:00'),
(6, 2, 'Departed Hub', 'Loaded for transit', '2026-09-06 14:30:00'),

-- TRK1007 (id 7)
(7, 3, 'Booked', 'Express booking Delhi', '2026-09-07 10:00:00'),
(7, 3, 'Departed Hub', 'In transit to Indore', '2026-09-07 11:00:00'),
(7, 2, 'Arrived at Hub', 'Arrived at Indore', '2026-09-08 18:00:00'),
(7, 2, 'Out for Delivery', 'Out for delivery', '2026-09-09 11:00:00'),
(7, 2, 'Delivered', 'Delivered to Amit Patil', '2026-09-09 15:30:00'),

-- TRK1008 (id 8)
(8, 5, 'Booked', 'Booked at Nagpur Hub', '2026-09-08 16:30:00'),
(8, 5, 'Departed Hub', 'Departed for Mumbai', '2026-09-09 08:00:00'),
(8, 4, 'Arrived at Hub', 'Arrived at Mumbai West Hub', '2026-09-10 05:00:00'),
(8, 4, 'Out for Delivery', 'Out for delivery', '2026-09-11 13:00:00'),
(8, 4, 'Delivered', 'Delivered to Ananya Deshmukh', '2026-09-11 18:00:00'),

-- TRK1009 (id 9) - Multi-trip parcel
(9, 1, 'Booked', 'Heavy shipment booked at Bhopal', '2026-09-09 11:15:00'),
(9, 1, 'Picked Up', 'Handled with mechanical lift', '2026-09-09 12:00:00'),
(9, 1, 'Departed Hub', 'Trip 7 departed for Indore', '2026-09-09 13:00:00'),
(9, 2, 'Arrived at Hub', 'Transferred at Indore sorting hub', '2026-09-09 19:00:00'),
(9, 2, 'Departed Hub', 'Trip 11 departed for Mumbai West', '2026-09-11 13:00:00'),

-- TRK1010 (id 10) - Delivered late to Delhi
(10, 4, 'Booked', 'Fragile express booked Mumbai', '2026-09-10 09:30:00'),
(10, 4, 'Departed Hub', 'Departed for Delhi', '2026-09-11 12:00:00'),
(10, 3, 'Arrived at Hub', 'Arrived at Delhi North', '2026-09-12 09:00:00'),
(10, 3, 'Out for Delivery', 'Out for delivery', '2026-09-13 08:00:00'),
(10, 3, 'Delivered', 'Delivered 1 day late', '2026-09-13 10:15:00'),

-- TRK1011 (id 11) - In Transit
(11, 1, 'Booked', 'Express parcel to Nagpur', '2026-09-11 15:00:00'),
(11, 1, 'Picked Up', 'Picked up by local runner', '2026-09-11 16:00:00'),
(11, 1, 'Departed Hub', 'Departed Bhopal for Indore hub', '2026-09-12 08:00:00'),
(11, 2, 'Arrived at Hub', 'Transit scan at Indore', '2026-09-12 14:00:00'),

-- TRK1012 (id 12) - Booked
(12, 3, 'Booked', 'Booking confirmed at Delhi Hub', '2026-09-12 12:00:00'),

-- TRK1013 (id 13) - Out for Delivery
(13, 5, 'Booked', 'Booked at Nagpur for Indore', '2026-09-13 14:15:00'),
(13, 5, 'Departed Hub', 'Departed on Trip 13', '2026-09-13 15:30:00'),
(13, 2, 'Arrived at Hub', 'Arrived at Indore', '2026-09-14 06:00:00'),
(13, 2, 'Out for Delivery', 'Out for delivery to customer', '2026-09-14 09:00:00'),

-- TRK1014 (id 14) - Failed delivery 1 (Sender Rohit Mehta)
(14, 1, 'Booked', 'Booked at Bhopal for Delhi', '2026-09-14 10:30:00'),
(14, 1, 'Departed Hub', 'Departed on Trip 14', '2026-09-14 11:30:00'),
(14, 3, 'Arrived at Hub', 'Arrived at Delhi Hub', '2026-09-15 08:00:00'),
(14, 3, 'Out for Delivery', 'Delivery attempt 1', '2026-09-15 11:00:00'),
(14, 3, 'Failed', 'Receiver address could not be located', '2026-09-15 16:00:00'),

-- TRK1015 (id 15) - Failed delivery 2 (Sender Amit Patil)
(15, 2, 'Booked', 'Booked at Indore for Mumbai', '2026-09-15 11:45:00'),
(15, 2, 'Departed Hub', 'Departed Indore', '2026-09-15 13:00:00'),
(15, 4, 'Arrived at Hub', 'Arrived Mumbai Hub', '2026-09-16 09:00:00'),
(15, 4, 'Out for Delivery', 'Delivery attempt 1', '2026-09-16 12:00:00'),
(15, 4, 'Failed', 'Customer refused delivery / premises locked', '2026-09-16 17:30:00');

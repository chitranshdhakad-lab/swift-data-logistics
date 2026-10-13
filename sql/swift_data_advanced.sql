-- =====================================================================
-- Swift Data Logistics DBMS
-- File: swift_data_advanced.sql
-- Description: Advanced database features:
--              1. View (v_live_shipment_status)
--              2. Trigger (trg_event_updates_shipment)
--              3. Stored Procedure with Transaction (sp_assign_shipment_to_trip)
--              4. Live Demonstration & Verification statements
-- =====================================================================

USE swift_data;

-- ---------------------------------------------------------------------
-- 1. VIEW: v_live_shipment_status
-- Consolidates shipments, parties, route cities, and the latest event
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS v_live_shipment_status;

CREATE VIEW v_live_shipment_status AS
SELECT 
    s.shipment_id,
    s.tracking_number,
    cs.name AS sender_name,
    cr.name AS receiver_name,
    hs.city AS from_city,
    hd.city AS to_city,
    s.weight_kg,
    s.service_type,
    s.current_status,
    s.booking_date,
    s.expected_date,
    s.delivered_date,
    s.cost,
    le.status AS latest_event_status,
    le.event_time AS latest_event_time,
    lh.name AS latest_event_hub,
    le.remarks AS latest_event_remarks
FROM Shipment s
JOIN Customer cs ON cs.customer_id = s.sender_id
JOIN Customer cr ON cr.customer_id = s.receiver_id
JOIN Hub hs ON hs.hub_id = s.source_hub_id
JOIN Hub hd ON hd.hub_id = s.dest_hub_id
LEFT JOIN Tracking_Event le 
    ON le.event_id = (
        SELECT e.event_id 
        FROM Tracking_Event e
        WHERE e.shipment_id = s.shipment_id
        ORDER BY e.event_time DESC, e.event_id DESC 
        LIMIT 1
    )
LEFT JOIN Hub lh ON lh.hub_id = le.hub_id;

-- ---------------------------------------------------------------------
-- 2. TRIGGER: trg_event_updates_shipment
-- Fires AFTER INSERT on Tracking_Event to sync Shipment status automatically
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_event_updates_shipment;

DELIMITER $$

CREATE TRIGGER trg_event_updates_shipment
AFTER INSERT ON Tracking_Event 
FOR EACH ROW
BEGIN
    UPDATE Shipment
    SET current_status = CASE NEW.status
            WHEN 'Booked'           THEN 'Booked'
            WHEN 'Out for Delivery' THEN 'Out for Delivery'
            WHEN 'Delivered'        THEN 'Delivered'
            WHEN 'Failed'           THEN 'Failed'
            ELSE 'In Transit'
        END,
        delivered_date = IF(NEW.status = 'Delivered', 
                            NEW.event_time, 
                            delivered_date)
    WHERE shipment_id = NEW.shipment_id;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 3. STORED PROCEDURE: sp_assign_shipment_to_trip
-- Atomically loads a parcel onto a trip, verifies vehicle capacity,
-- updates vehicle load, and logs a transit tracking event.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_assign_shipment_to_trip;

DELIMITER $$

CREATE PROCEDURE sp_assign_shipment_to_trip(
    IN p_trip_id INT,
    IN p_shipment_id INT
)
proc_label: BEGIN
    DECLARE v_vehicle_id INT;
    DECLARE v_from_hub INT;
    DECLARE v_trip_status VARCHAR(20);
    DECLARE v_weight DECIMAL(8,2);
    DECLARE v_shipment_status VARCHAR(20);
    DECLARE v_capacity DECIMAL(8,2);
    DECLARE v_current_load DECIMAL(8,2);

    -- Exit handler ensures automatic rollback on any database exception
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Step 1: Lock and validate Trip
    SELECT vehicle_id, from_hub_id, status 
    INTO v_vehicle_id, v_from_hub, v_trip_status
    FROM Trip 
    WHERE trip_id = p_trip_id 
    FOR UPDATE;

    IF v_vehicle_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trip not found';
    END IF;

    IF v_trip_status NOT IN ('Planned', 'Ongoing') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Trip is not active for loading';
    END IF;

    -- Step 2: Lock and validate Shipment
    SELECT weight_kg, current_status 
    INTO v_weight, v_shipment_status
    FROM Shipment 
    WHERE shipment_id = p_shipment_id 
    FOR UPDATE;

    IF v_weight IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shipment not found';
    END IF;

    IF v_shipment_status = 'Delivered' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Shipment is already delivered';
    END IF;

    -- Step 3: Lock vehicle and verify weight capacity
    SELECT capacity_kg, current_load_kg 
    INTO v_capacity, v_current_load
    FROM Vehicle 
    WHERE vehicle_id = v_vehicle_id 
    FOR UPDATE;

    IF (v_current_load + v_weight) > v_capacity THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Vehicle capacity exceeded';
    END IF;

    -- Step 4: Insert junction record
    INSERT INTO Trip_Shipment (trip_id, shipment_id, loaded_at)
    VALUES (p_trip_id, p_shipment_id, NOW());

    -- Step 5: Increment vehicle load
    UPDATE Vehicle
    SET current_load_kg = current_load_kg + v_weight
    WHERE vehicle_id = v_vehicle_id;

    -- Step 6: Log departed event (trigger will sync shipment status to In Transit)
    INSERT INTO Tracking_Event (shipment_id, hub_id, status, remarks, event_time)
    VALUES (p_shipment_id, v_from_hub, 'Departed Hub', 
            CONCAT('Loaded onto trip #', p_trip_id), NOW());

    COMMIT;
END$$

DELIMITER ;

-- =====================================================================
-- 4. DEMO & VERIFICATION COMMANDS
-- (Uncomment and run in MySQL Workbench during Viva demonstration)
-- =====================================================================
-- Demo 1: Test the View
-- SELECT * FROM v_live_shipment_status WHERE current_status = 'In Transit';

-- Demo 2: Test Stored Procedure Successful Loading
-- CALL sp_assign_shipment_to_trip(12, 6);

-- Demo 3: Test Trigger Sync
-- INSERT INTO Tracking_Event (shipment_id, hub_id, status, remarks, event_time)
-- VALUES (11, 5, 'Delivered', 'Delivered at destination hub counter', NOW());
-- SELECT tracking_number, current_status, delivered_date FROM Shipment WHERE shipment_id = 11;

-- =====================================================================
-- Swift Data Logistics DBMS
-- File: swift_data_schema.sql
-- Description: DDL script creating database, 8 normalized tables, 
--              14 foreign keys, 7 CHECK constraints, and 3 explicit indexes.
-- DBMS: MySQL 8.0 (InnoDB engine)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS swift_data;
USE swift_data;

-- Clean teardown in reverse foreign key order if re-running
DROP TABLE IF EXISTS Tracking_Event;
DROP TABLE IF EXISTS Trip_Shipment;
DROP TABLE IF EXISTS Trip;
DROP TABLE IF EXISTS Shipment;
DROP TABLE IF EXISTS Vehicle;
DROP TABLE IF EXISTS Driver;
DROP TABLE IF EXISTS Customer;
DROP TABLE IF EXISTS Hub;

-- ---------------------------------------------------------------------
-- 1. Table: Hub (Master)
-- Sorting and storage centres in five cities
-- ---------------------------------------------------------------------
CREATE TABLE Hub (
    hub_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    capacity INT NOT NULL,
    CONSTRAINT chk_hub_capacity CHECK (capacity > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. Table: Customer (Master)
-- Senders and receivers of shipments across service areas
-- ---------------------------------------------------------------------
CREATE TABLE Customer (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100) UNIQUE,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(50) NOT NULL,
    pincode CHAR(6) NOT NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. Table: Driver (Master)
-- Logistics personnel assigned to designated home hubs
-- ---------------------------------------------------------------------
CREATE TABLE Driver (
    driver_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    license_no VARCHAR(20) NOT NULL UNIQUE,
    hub_id INT NOT NULL,
    status ENUM('Active', 'On Leave', 'Inactive') NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_driver_hub FOREIGN KEY (hub_id) 
        REFERENCES Hub(hub_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. Table: Vehicle (Master)
-- Delivery fleet (Bikes, Vans, Trucks) with load monitoring
-- ---------------------------------------------------------------------
CREATE TABLE Vehicle (
    vehicle_id INT AUTO_INCREMENT PRIMARY KEY,
    plate_no VARCHAR(15) NOT NULL UNIQUE,
    type ENUM('Bike', 'Van', 'Truck') NOT NULL,
    capacity_kg DECIMAL(8,2) NOT NULL,
    current_load_kg DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    hub_id INT NOT NULL,
    status ENUM('Available', 'On Trip', 'Maintenance') NOT NULL DEFAULT 'Available',
    CONSTRAINT fk_vehicle_hub FOREIGN KEY (hub_id) 
        REFERENCES Hub(hub_id) ON DELETE RESTRICT,
    CONSTRAINT chk_vehicle_capacity CHECK (capacity_kg > 0),
    CONSTRAINT chk_vehicle_load CHECK (current_load_kg >= 0 AND current_load_kg <= capacity_kg)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. Table: Shipment (Transaction)
-- Core delivery request entity with tracking and delivery status
-- ---------------------------------------------------------------------
CREATE TABLE Shipment (
    shipment_id INT AUTO_INCREMENT PRIMARY KEY,
    tracking_number VARCHAR(20) NOT NULL UNIQUE,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    source_hub_id INT NOT NULL,
    dest_hub_id INT NOT NULL,
    weight_kg DECIMAL(8,2) NOT NULL,
    is_fragile BOOLEAN NOT NULL DEFAULT FALSE,
    service_type ENUM('Standard', 'Express') NOT NULL DEFAULT 'Standard',
    booking_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expected_date DATE NOT NULL,
    delivered_date DATETIME NULL,
    current_status ENUM('Booked', 'In Transit', 'Out for Delivery', 'Delivered', 'Failed') NOT NULL DEFAULT 'Booked',
    cost DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_shipment_sender FOREIGN KEY (sender_id) 
        REFERENCES Customer(customer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_shipment_receiver FOREIGN KEY (receiver_id) 
        REFERENCES Customer(customer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_shipment_source_hub FOREIGN KEY (source_hub_id) 
        REFERENCES Hub(hub_id) ON DELETE RESTRICT,
    CONSTRAINT fk_shipment_dest_hub FOREIGN KEY (dest_hub_id) 
        REFERENCES Hub(hub_id) ON DELETE RESTRICT,
    CONSTRAINT chk_shipment_sender_receiver CHECK (sender_id <> receiver_id),
    CONSTRAINT chk_shipment_weight CHECK (weight_kg > 0),
    CONSTRAINT chk_shipment_cost CHECK (cost >= 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. Table: Trip (Transaction)
-- Dispatched vehicle route between two hubs driven by one driver
-- ---------------------------------------------------------------------
CREATE TABLE Trip (
    trip_id INT AUTO_INCREMENT PRIMARY KEY,
    driver_id INT NOT NULL,
    vehicle_id INT NOT NULL,
    from_hub_id INT NOT NULL,
    to_hub_id INT NOT NULL,
    start_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time DATETIME NULL,
    status ENUM('Planned', 'Ongoing', 'Completed', 'Cancelled') NOT NULL DEFAULT 'Planned',
    CONSTRAINT fk_trip_driver FOREIGN KEY (driver_id) 
        REFERENCES Driver(driver_id) ON DELETE RESTRICT,
    CONSTRAINT fk_trip_vehicle FOREIGN KEY (vehicle_id) 
        REFERENCES Vehicle(vehicle_id) ON DELETE RESTRICT,
    CONSTRAINT fk_trip_from_hub FOREIGN KEY (from_hub_id) 
        REFERENCES Hub(hub_id) ON DELETE RESTRICT,
    CONSTRAINT fk_trip_to_hub FOREIGN KEY (to_hub_id) 
        REFERENCES Hub(hub_id) ON DELETE RESTRICT,
    CONSTRAINT chk_trip_end_time CHECK (end_time IS NULL OR end_time > start_time)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. Table: Trip_Shipment (Junction Table)
-- Resolves M:N relationship between Trips and Shipments
-- ---------------------------------------------------------------------
CREATE TABLE Trip_Shipment (
    trip_id INT NOT NULL,
    shipment_id INT NOT NULL,
    loaded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (trip_id, shipment_id),
    CONSTRAINT fk_ts_trip FOREIGN KEY (trip_id) 
        REFERENCES Trip(trip_id) ON DELETE CASCADE,
    CONSTRAINT fk_ts_shipment FOREIGN KEY (shipment_id) 
        REFERENCES Shipment(shipment_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. Table: Tracking_Event (History Log)
-- Append-only milestone diary for parcel movement
-- ---------------------------------------------------------------------
CREATE TABLE Tracking_Event (
    event_id INT AUTO_INCREMENT PRIMARY KEY,
    shipment_id INT NOT NULL,
    hub_id INT NULL,
    status ENUM('Booked', 'Picked Up', 'Arrived at Hub', 'Departed Hub', 'Out for Delivery', 'Delivered', 'Failed') NOT NULL,
    remarks VARCHAR(255) NULL,
    event_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_te_shipment FOREIGN KEY (shipment_id) 
        REFERENCES Shipment(shipment_id) ON DELETE CASCADE,
    CONSTRAINT fk_te_hub FOREIGN KEY (hub_id) 
        REFERENCES Hub(hub_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9. Explicit Indexes
-- Optimized lookup structures for high-frequency queries
-- ---------------------------------------------------------------------
-- Fast retrieval of shipment tracking timelines in chronological order
CREATE INDEX idx_event_shipment_time ON Tracking_Event (shipment_id, event_time);

-- Fast counting and filtering by live shipment status
CREATE INDEX idx_shipment_status ON Shipment (current_status);

-- Driver performance lookups by date range
CREATE INDEX idx_trip_driver ON Trip (driver_id, start_time);

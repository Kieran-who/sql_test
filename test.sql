-- TODO: test below; INSERT statements with test data

-- Vehicle (supertype)
-- We have a vehicle supertype as the following attributes are shared across preowned and new vehicles
CREATE TABLE Vehicle (
    VIN CHAR(17) NOT NULL PRIMARY KEY,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INT NOT NULL,
    odometer INT CHECK (odometer >= 0),
    colour VARCHAR(50) NOT NULL,
    transmissionType VARCHAR(50) NOT NULL,
    soldStatus BOOLEAN DEFAULT false, -- false: still available for sale, true: sold
    price DECIMAL(8,0) CHECK (price > 0),
    description VARCHAR(255)
);

-- Supertype for persons
-- We use a supertype as there are two subtypes (customer and salesperson) who share these attributes
CREATE TABLE Person (
    pid INT NOT NULL PRIMARY KEY,
    firstName VARCHAR(50) NOT NULL,
    lastName VARCHAR(50) NOT NULL,
    mobile VARCHAR(20) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
);

-- SalesPerson (subtype of Person)
CREATE TABLE SalesPerson (
    pid INT NOT NULL PRIMARY KEY,
    -- when superclass deleted, so too should the subclass
    FOREIGN KEY (pid) REFERENCES Person(pid) ON DELETE CASCADE,
    grossSalary DECIMAL(10,2) CHECK (grossSalary > 0),
    commissionRate DECIMAL(5,2) CHECK (commissionRate > 0 AND commissionRate < 0.1)
    );

-- TestDrive
CREATE TABLE TestDrive (
    tid INT NOT NULL PRIMARY KEY,
    VIN CHAR(17) NOT NULL,    
    testerEmail VARCHAR(100) NOT NULL,
    salesPersonId INT NOT NULL,
    testDate DATE NOT NULL,
    testTime TIME NOT NULL,
    feedback VARCHAR(255),    
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN),
    FOREIGN KEY (salesPersonId) REFERENCES SalesPerson(pid)
);

-- Customer (subtype of Person)
-- Customer is created after TestDrive as we have a customer FK attribe pointing to TestDrive
-- We have the testDriveId FK to satisfy the condition that a customer must have a TestDrive (this must be included in the insert statement)
-- A customer can only be created with a sale record. We ensure this constraint by the check_customer_has_sale() explained below
-- As a customer can only created with a sale record, it must be inserted in the same transaction as a sale
CREATE TABLE Customer (
    pid INT NOT NULL PRIMARY KEY,
    -- when superclass deleted, so too should the subclass
    FOREIGN KEY (pid) REFERENCES Person(pid) ON DELETE CASCADE,
    testDriveId INT NOT NULL,
    FOREIGN KEY (testDriveId) REFERENCES TestDrive(tid),
    driversLicence VARCHAR(50) NOT NULL UNIQUE,
    apartmentNo VARCHAR(10),
    streetNo VARCHAR(10),
    CHECK (apartmentNo IS NOT NULL OR streetNo IS NOT NULL), -- All addresses need to have either an apartment number or street number
    street VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postcode CHAR(4) NOT NULL, -- Aus post codes are 4 digits
    country CHAR(2) NOT NULL -- assumed we can just use 2 digit country codes here??
);

-- NewVehicle (subtype of Vehicle)
-- We have a seperate table for NewVehicle to track the addition of aftermarket options which can only be applied to new vehicles
CREATE TABLE NewVehicle (
    VIN CHAR(17) NOT NULL PRIMARY KEY,
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN) ON DELETE CASCADE
);

-- PreownedVehicle (subtype of Vehicle)
-- Preowned has the additional attribute of pre_owner
CREATE TABLE PreownedVehicle (
    VIN CHAR(17) NOT NULL PRIMARY KEY,
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN) ON DELETE CASCADE,
    pre_owner VARCHAR(100) NOT NULL
);

-- TradedInVehicle (subtype of PreownedVehicle)
-- We set the TradedInVehicle as a subclass of PreownedVehicle as logically, it made more sense as a TradedInVehicle is always going to be PreownedVehicle
-- A tradeinVehicle is only added to the db when a customer trades in their vehicle as part of a sale
-- When a sale completes with a reference to a TradedInVehicle there is a trigger (trig_move_new_vehicle_to_preowned_func) that updates the relevant records to note this vehicle is for sale (as per the requirements)
CREATE TABLE TradedInVehicle (
    VIN CHAR(17) NOT NULL PRIMARY KEY,
    -- As TradedInVehicle is subclass of PreownedVehicle we set ON DELETE CASCADE as no instances where the subclass should exist without the superclass item
    FOREIGN KEY (VIN) REFERENCES PreownedVehicle(VIN) ON DELETE CASCADE,   
    mech_condition VARCHAR(10) CHECK (mech_condition IN ('poor', 'fair', 'good', 'excellent')),
    body_condition VARCHAR(10) CHECK (body_condition IN ('poor', 'fair', 'good', 'excellent')),
    tradeInValue DECIMAL(8,0) CHECK (tradeInValue > 0)
);

-- ImageGallery (stores images for a given vehicle as there can be many)
CREATE TABLE Images (
    VIN CHAR(17) NOT NULL,
    imgLink VARCHAR(255) NOT NULL,
    PRIMARY KEY (VIN, imgLink),
    -- As these images are related purely to a specific vehicle only, if that vehicle is deleted, images should also be deleted.
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN) ON DELETE CASCADE
);

-- Sale
-- It is assumed that sale records should not be deleted so there are no ON DELETE CASCADE clauses set, application logic can handle this if necessary
-- The PK of custeromID and saleDate ensures that only a customer can only participate in one sale per day
CREATE TABLE Sale (
    customerId INT NOT NULL,
    saleDate DATE NOT NULL,
    saleVIN CHAR(17) NOT NULL,
    tradedInVIN CHAR(17),
    salesPersonId INT NOT NULL,
    discountPrice DECIMAL(8,0) CHECK (discountPrice > 0),
    basePrice DECIMAL(8,0) CHECK (basePrice > 0),
    soldStatus BOOLEAN DEFAULT false, -- false: still pending sale (i.e. payment has not been finalised), true: sold        
    PRIMARY KEY (customerId, saleDate),
    FOREIGN KEY (customerId) REFERENCES Customer(pid),
    FOREIGN KEY (saleVIN) REFERENCES Vehicle(VIN),
    FOREIGN KEY (tradedInVIN) REFERENCES TradedInVehicle(VIN),
    FOREIGN KEY (salesPersonId) REFERENCES SalesPerson(pid)
);

-- Payment
CREATE TABLE Payment (
    customerId INT NOT NULL,
    saleDate DATE NOT NULL,
    -- Auto increment the payment identity
    instalmentNo INT GENERATED ALWAYS AS IDENTITY,
    paymentDate DATE NOT NULL,
    amount DECIMAL(10,2) CHECK (amount > 0),
    type VARCHAR(15) CHECK (type IN ('cash','credit card','bank transfer','bank financing')),
    PRIMARY KEY (customerId, saleDate, instalmentNo),
    -- As payment is a weak entity, any entries should be deleted if the strong entity is deleted.
    FOREIGN KEY (customerId, saleDate) REFERENCES Sale(customerId, saleDate) ON DELETE CASCADE
);

-- BankLoan
CREATE TABLE BankFinancing (
    customerId INT NOT NULL,
    saleDate DATE NOT NULL,
    bank VARCHAR(50) NOT NULL,
    applicationDate DATE NOT NULL,
    loanTerm INT NOT NULL CHECK (loanTerm >= 12 AND loanTerm <= 50),
    interestRate DECIMAL(5,2) NOT NULL,
    loanValue DECIMAL(10,2) NOT NULL CHECK (loanValue > 0),
    proofPresented BOOLEAN DEFAULT false, -- false: proof not presented, true: proof presented
    PRIMARY KEY (customerId, saleDate),
    -- As BankLoan is tied purely to a sale, if the sale is deleted so too should the associated BankLoan row.
    FOREIGN KEY (customerId, saleDate) REFERENCES Sale(customerId, saleDate) ON DELETE CASCADE
);

-- AfterMarketOption
CREATE TABLE AfterMarketOption (
    optionId INT NOT NULL PRIMARY KEY,
    name VARCHAR(50),
    description VARCHAR(255)
);

-- IsAddedTo
-- We check that there are no more than 8 IsAddedTo rows for each sale using the trigger check_max_options_func
-- We also have another trigger (check_new_vehicle_only_func) which ensures AfterMarketOption are associated with sales involving new cars
CREATE TABLE IsAddedTo (
    optionId INT NOT NULL,
    saleDate DATE NOT NULL,
    customerId INT NOT NULL,
    VIN CHAR(17) NOT NULL,
    cost DECIMAL(10,2) CHECK (cost > 0),
    PRIMARY KEY (optionId, saleDate, customerId),
    FOREIGN KEY (optionId) REFERENCES AfterMarketOption(optionId),
    -- As IsAddedTo is tied purely to a sale, if the sale is deleted so too should the associated IsAddedTo row/s.
    FOREIGN KEY (customerId, saleDate) REFERENCES Sale(customerId, saleDate) ON DELETE CASCADE,
    FOREIGN KEY (VIN) REFERENCES NewVehicle(VIN)    
);

-- Need to constrain the maximum IsAddedTo count per sale to 8
CREATE OR REPLACE FUNCTION check_max_options_func()
RETURNS TRIGGER AS $$
DECLARE
  option_count INT;
BEGIN
  SELECT COUNT(*) 
    INTO option_count
    FROM IsAddedTo
    WHERE saleDate = NEW.saleDate
    AND customerId = NEW.customerId;

  IF option_count >= 8 THEN
    RAISE EXCEPTION 'Cannot add more than 8 AfterMarketOptions per Sale.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER checkMaxOptions
BEFORE INSERT ON IsAddedTo
FOR EACH ROW
EXECUTE FUNCTION check_max_options_func();

-- Constrain the addition of Aftermarket options to new vehicles
-- We have a seperate new vehicle table with just new vehicles so we can do a lookup to see if the sale's VIN exists in that table. If not, we prevent the insert
CREATE OR REPLACE FUNCTION check_new_vehicle_only_func()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM NewVehicle
    WHERE VIN = NEW.VIN
  ) THEN
    RAISE EXCEPTION 'AfterMarketOptions are only allowed for new-vehicle Sales.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER checkNewVehicleOnly
BEFORE INSERT ON IsAddedTo
FOR EACH ROW
EXECUTE FUNCTION check_new_vehicle_only_func();

-- To ensure the above trigger works consistently (checkNewVehicleOnly), we need to ensure any new sold vehicles are removed from the new vehicle table.
-- We are assuming here that the dealership still wants to record a history of sold vehicles (as opposed to just deleting from the db) so we move it to the PreownedVehicle table
-- We can add pre_owned here also (set as 'Dealership' which is the previous owner once a new vehicle is sold)
CREATE OR REPLACE FUNCTION trig_move_new_vehicle_to_preowned_func()
RETURNS TRIGGER AS $$
BEGIN
  -- Only run if the Sale is newly sold or updated to sold.
  IF NEW.soldStatus = TRUE THEN
    IF EXISTS (
      SELECT 1
      FROM NewVehicle
      WHERE VIN = NEW.saleVIN
    ) THEN
      -- Remove from NewVehicle
      DELETE FROM NewVehicle
      WHERE VIN = NEW.saleVIN;

      -- Insert into PreownedVehicle
      INSERT INTO PreownedVehicle (VIN, pre_owner)
      VALUES (NEW.saleVIN, 'Dealership');

      -- Update the master Vehicle table to set that VIN as sold
      UPDATE Vehicle
      SET soldStatus = True
      WHERE VIN = NEW.saleVIN;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trig_move_new_vehicle_to_preowned
AFTER INSERT OR UPDATE ON Sale
FOR EACH ROW
EXECUTE FUNCTION trig_move_new_vehicle_to_preowned_func();

-- Trigger to update tradedInVehicle's vehicle status to not sold with insert of Sale (referencing line from assignment description -> 'We assume that once the vehicle is traded in, it will be put on sale immediately')
-- We trigger on INSERT and UPDATE in the edge case that a sale record is updated at a later stage to include the tradedInVehicle
-- We also assume that the dealership wants to maintain a record of tradedInVehicles (i.e. instead of deleting them from the db)
CREATE OR REPLACE FUNCTION trig_add_traded_in_vehicle_to_preowned_func()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tradedInVIN IS NOT NULL THEN
      -- Update the superclass Vehicle table to set that VIN as unsold
      UPDATE Vehicle
      SET soldStatus = false
      WHERE VIN = NEW.tradedInVIN;
    END IF;  

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trig_add_traded_in_vehicle_to_preowned
AFTER INSERT OR UPDATE ON Sale
FOR EACH ROW
EXECUTE FUNCTION trig_add_traded_in_vehicle_to_preowned_func();

-- A customer must be associated with at least one vehicle purchase record
-- This trigger is fired AFTER a row is inserted or updated in Customer. It is checked at the end of the transaction.
-- It needs to be fired after otherwise, we would never be able to insert a Customer and its corresponding Sale within the same transaction
-- As we have customerId as part of the PK of sale, customer must first be inserted, then sale, then the deferred checks run.
CREATE OR REPLACE FUNCTION check_customer_has_sale()
RETURNS TRIGGER AS $$
DECLARE
    sale_count INT;
BEGIN
    SELECT COUNT(*)
      INTO sale_count
      FROM Sale
     WHERE customerId = NEW.pid;

    IF sale_count = 0 THEN
        RAISE EXCEPTION 'Customer % must have at least one vehicle purchase record.', NEW."pid";
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER cst_customer_has_sale
AFTER INSERT OR UPDATE ON Customer
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_customer_has_sale();

-- A tradedInVehicle must be registered to the buyer's name
-- This means on the create of a tradedInVehicle, we need to check that the pre_owned parent classes's pre_owner exists in the Customer table 
-- and that the customerId is the same as the one in the Sale table
CREATE OR REPLACE FUNCTION check_traded_in_vehicle_insert_update()
RETURNS TRIGGER AS $$
DECLARE
    pre_owner_name VARCHAR(100);
    matching_customer_count INT;
BEGIN
    -- Get the pre_owner name from the PreownedVehicle parent table
    SELECT pre_owner INTO pre_owner_name
    FROM PreownedVehicle
    WHERE VIN = NEW.VIN;

    IF pre_owner_name IS NULL THEN
        RAISE EXCEPTION 'PreownedVehicle entry missing for VIN %', NEW.VIN;
    END IF;

    -- Check if there is at least one Sale where tradedInVIN matches NEW.VIN
    -- and the customer associated with that sale matches pre_owner_name
    SELECT COUNT(*)
    INTO matching_customer_count
    FROM Sale s
    JOIN Customer c ON s.customerId = c.pid
    JOIN Person p ON c.pid = p.pid
    WHERE s.tradedInVIN = NEW.VIN
      AND CONCAT(p.firstName, ' ', p.lastName) = pre_owner_name;

    IF matching_customer_count = 0 THEN
        RAISE EXCEPTION 'Traded-in vehicle % must have a corresponding Sale with matching customer name %', NEW.VIN, pre_owner_name;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on TradedInVehicle to enforce this constraint
CREATE CONSTRAINT TRIGGER trg_check_traded_in_vehicle_insert_update
AFTER INSERT OR UPDATE ON TradedInVehicle
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_traded_in_vehicle_insert_update();

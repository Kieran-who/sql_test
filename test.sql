-- TODO: test below; INSERT statements with test data

-- Supertype for persons
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
    FOREIGN KEY (pid) REFERENCES Person(pid) ON DELETE CASCADE,
    grossSalary DECIMAL(10,2) CHECK (grossSalary > 0),
    commissionRate DECIMAL(5,2) CHECK (commissionRate > 0 AND commissionRate < 0.1)
    );

-- Customer (subtype of Person)
CREATE TABLE Customer (
    pid INT NOT NULL PRIMARY KEY,
    FOREIGN KEY (pid) REFERENCES Person(pid) ON DELETE CASCADE,
    driversLicence VARCHAR(50) NOT NULL UNIQUE, -- Didn't specify licence as PK as I believe the pk needs to be the same as the Person superclass
    apartmentNo VARCHAR(10),
    streetNo VARCHAR(10),
    CHECK (apartmentNo IS NOT NULL OR streetNo IS NOT NULL), -- All addresses need to have either an apartment number or street number
    street VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postcode CHAR(4) NOT NULL, -- Aus post codes are 4 digits
    country CHAR(2) NOT NULL -- assumed we can just use 2 digit country codes here??
);

-- Vehicle (supertype)
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

-- NewVehicle (subtype of Vehicle)
CREATE TABLE NewVehicle (
    VIN CHAR(17) NOT NULL PRIMARY KEY,
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN) ON DELETE CASCADE
);

-- PreownedVehicle (subtype of Vehicle)
CREATE TABLE PreownedVehicle (
    VIN CHAR(17) NOT NULL PRIMARY KEY,
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN) ON DELETE CASCADE,
    pre_owner VARCHAR(100) NOT NULL
);

-- TradedInVehicle (subtype of PreownedVehicle)
CREATE TABLE TradedInVehicle (
    VIN CHAR(17) NOT NULL PRIMARY KEY,
    -- FOREIGN KEY (VIN) REFERENCES PreownedVehicle(VIN) ON DELETE CASCADE,
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN) ON DELETE CASCADE, -- SEE COMMENTS IN DRAW.IO
    mech_condition VARCHAR(10) CHECK (mech_condition IN ('poor', 'fair', 'good', 'excellent')),
    body_condition VARCHAR(10) CHECK (body_condition IN ('poor', 'fair', 'good', 'excellent')),
    tradeInValue DECIMAL(8,0) CHECK (tradeInValue > 0),
    registeredName VARCHAR(100) NOT NULL -- added this
);

-- ImageGallery (stores images for a given vehicle)
CREATE TABLE Images (
    VIN CHAR(17) NOT NULL,
    imgLink VARCHAR(255) NOT NULL,
    PRIMARY KEY (VIN, imgLink),
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN) ON DELETE CASCADE
);

-- TestDrive
-- For second approach we assume the dealership will take the minimum required details for the Person superclass (email, name, mobile)
CREATE TABLE TestDrive (
    VIN CHAR(17) NOT NULL,
    ------------------------------------------------------------
    -- TO DECIDE BEST APPROACH FOR STORING TEST DRIVER'S DETAILS
    ------------------------------------------------------------
    -- customerId INT NOT NULL,
    -- personId INT NOT NULL,
    -- testerEmail VARCHAR(100) NOT NULL,
    salesPersonId INT NOT NULL,
    testDate DATE NOT NULL,
    testTime TIME NOT NULL,
    feedback VARCHAR(255),
    PRIMARY KEY (VIN, testDate, testTime),
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN),
    -- FOREIGN KEY (customerId) REFERENCES Customer(pid),
    FOREIGN KEY (personId) REFERENCES Person(pid), -- if we use this approach delete customerId FK and uncomment this line.
    FOREIGN KEY (salesPersonId) REFERENCES SalesPerson(pid)
);

-- Sale
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
    instalmentNo INT GENERATED ALWAYS AS IDENTITY, -- I believe this statement ensures the instalmentNo is generated automatically (but should definitely test, as not sure if it increments starting at 1 or if random, etc...)
    amount DECIMAL(10,2) CHECK (amount > 0),
    type VARCHAR(15) CHECK (type IN ('cash','credit card','bank transfer','bank financing')),
    PRIMARY KEY (customerId, saleDate, instalmentNo),
    FOREIGN KEY (customerId, saleDate) REFERENCES Sale(customerId, saleDate) ON DELETE CASCADE
);

-- BankLoan
CREATE TABLE BankLoan (
    customerId INT NOT NULL,
    saleDate DATE NOT NULL,
    bank VARCHAR(50) NOT NULL,
    applicationDate DATE NOT NULL,
    loanTerm INT NOT NULL CHECK (loanTerm >= 12 AND loanTerm <= 50),
    interestRate DECIMAL(5,2) NOT NULL,
    loanValue DECIMAL(10,2) NOT NULL CHECK (loanValue > 0),
    proofPresented BOOLEAN DEFAULT false, -- false: proof not presented, true: proof presented
    PRIMARY KEY (customerId, saleDate),
    FOREIGN KEY (customerId, saleDate) REFERENCES Sale(customerId, saleDate) ON DELETE CASCADE
);

-- AfterMarketOption
CREATE TABLE AfterMarketOption (
    optionId INT NOT NULL PRIMARY KEY,
    name VARCHAR(50),
    description VARCHAR(255)
);

-- IsAddedTo
CREATE TABLE IsAddedTo (
    optionId INT NOT NULL,
    saleDate DATE NOT NULL,
    customerId INT NOT NULL,
    VIN CHAR(17) NOT NULL,
    cost DECIMAL(10,2) CHECK (cost > 0),
    PRIMARY KEY (optionId, saleDate, customerId),
    FOREIGN KEY (optionId) REFERENCES AfterMarketOption(optionId),
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

-- Constrain the addition of Aftermarket options to vehicles without pre_owner attribute
-- We have a seperate new vehicle table with just new vehicles so we can do a lookup to see if the sale's vin exists in that table
-- If not, we prevent the insert
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

-- To ensure the above trigger works consistently (checkNewVehicleOnly), we need to ensure any new sold vehicles are removed from the new vehicle table to the previous owned table
-- We are assuming here that the dealership still wants to record a history of sold vehicles (as opposed to just deleting from the db)
-- We can add pre_owned here also
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

-- Trigger to add tradedInVehicle to preowned with insert of Sale (referencing line from assignment description -> 'We assume that once the vehicle is traded in, it will be put on sale immediately')
-- Here we assume that on sale, we want to move the tradedInVehicle into the pre_owned vehicle list (be we ensure to only do that if not already present, i.e. in the case it was moved on insert and then an update retriggers logic)
-- We trigger on insert and sale in the edge case that a sale record is updated at a later stage to include the tradedInVehicle
-- We also assume that the dealership wants to maintain a record of tradedInVehicles (i.e. instead of deleting them from the db)
CREATE OR REPLACE FUNCTION trig_add_traded_in_vehicle_to_preowned_func()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tradedInVIN IS NOT NULL THEN
    -- If it's not already in PreownedVehicle, insert it
    IF NOT EXISTS (
      SELECT 1 
      FROM PreownedVehicle
      WHERE VIN = NEW.tradedInVIN
    ) THEN
      -- Insert the newly traded-in vehicle into PreownedVehicle
      INSERT INTO PreownedVehicle (VIN, pre_owner)
        SELECT t.VIN, t.registeredName
        FROM TradedInVehicle t
        WHERE t.VIN = NEW.tradedInVIN;

      -- Update the master Vehicle table to set that VIN as unsold
      UPDATE Vehicle
      SET soldStatus = false
      WHERE VIN = NEW.tradedInVIN;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trig_add_traded_in_vehicle_to_preowned
AFTER INSERT OR UPDATE ON Sale
FOR EACH ROW
EXECUTE FUNCTION trig_add_traded_in_vehicle_to_preowned_func();

-- A customer must be associated with at least one vehicle purchase record
-- This trigger is fired AFTER a row is inserted or updated in Customer. It is checked at the end of the transaction
-- It needs to be fired after otherwise, we would never be able to insert a Customer and its corresponding Sale within the same transaction
-- i.e. if a new customer we need to create the customer in the same transaction as a sale so that a customer record is associated with a sale.
-- as we have customerId as part of the PK of sale, customer must first be inserted, then sale, then the deferred checks run.
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

--------------------------------------------------------
-- TEST whether associated test drive record exists
-- TO UPDATE BASED ON HOW WE HANDLE TESTDRIVE
-- Below example works for storing email in testDrive
--------------------------------------------------------
CREATE OR REPLACE FUNCTION check_person_testdrives_before_customer()
RETURNS TRIGGER AS $$
DECLARE
    person_email VARCHAR(100);
    testdrive_count INT;
BEGIN
    -- Fetch the email of the Person row associated with the new Customer (stores as person_email var)
    SELECT email 
      INTO person_email
      FROM Person
     WHERE pid = NEW.pid;

    -- Check if there's a test drive record with that email
    SELECT COUNT(*)
      INTO testdrive_count
      FROM TestDrive
     WHERE testerEmail = person_email;

    IF testdrive_count = 0 THEN
        RAISE EXCEPTION
          'Person % (email: %) must have at least one TestDrive record before becoming a Customer.', 
           NEW.pid, person_email;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER cst_person_testdrives
AFTER INSERT ON Customer
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_person_testdrives_before_customer();

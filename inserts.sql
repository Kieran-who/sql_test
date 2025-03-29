------------------------------------------------------------------------------
-- 1) Insert some Person records.
------------------------------------------------------------------------------

BEGIN;
    INSERT INTO Person (pid, firstName, lastName, mobile, email)
    VALUES
      (101, 'Alice', 'Anderson', '0400000000', 'alice@example.com'),
      (102, 'Bob', 'Brown', '0411111111', 'bob@example.com'),
      (103, 'Carol', 'Carter', '0422222222', 'carol@example.com'),
      (200, 'Evan', 'Edwards', '0499999999', 'evan@example.com'),
      (300, 'Sales', 'One', '0412345678', 'sales1@example.com'),
      (301, 'Sales', 'Two', '0499998888', 'sales2@example.com'),
      (999, 'Lewis',  'Hamilton', '0491231234', 'zoe@example.com');
COMMIT;

------------------------------------------------------------------------------
-- 2) Convert some Persons to SalesPerson
------------------------------------------------------------------------------

BEGIN;
    INSERT INTO SalesPerson (pid, grossSalary, commissionRate)
    VALUES
      (300, 50000, 0.05),
      (301, 55000, 0.07);
COMMIT;

------------------------------------------------------------------------------
-- 3) Insert some Vehicle records (both NEW and PRE-owned)
------------------------------------------------------------------------------
BEGIN;
    -- Make sure the VINs are 17 chars each
    INSERT INTO Vehicle (VIN, make, model, year, odometer, colour, 
                         transmissionType, price, description)
    VALUES
      ('NEW0000000000001', 'Toyota', 'Corolla', 2023, 100, 'White', 'Auto', 25000, 'Newish Corolla'),
      ('NEW0000000000002', 'Honda', 'Civic',   2023,  50, 'Black', 'Auto', 27000, 'Brand-new Civic'),
      ('PRE0000000000001', 'Ford',  'Focus',   2020, 35000, 'Blue', 'Manual', 18000, 'Used Focus'),
	  ('PRE0000000000002', 'Ferrari',  'FastOne',2024, 95000, 'Red', 'Manual', 180000, 'Goes vroom'),
      ('TRA0000000000001', 'Mazda', '3',       2019, 60000, 'Red',  'Auto',  15000, 'Traded-in Mazda 3');

    -- Mark first two as "NewVehicle"
    INSERT INTO NewVehicle (VIN)
    VALUES
      ('NEW0000000000001'),
      ('NEW0000000000002');

    -- Mark two existing vehicles as "PreownedVehicle"
    INSERT INTO PreownedVehicle (VIN, pre_owner)
    VALUES
      ('PRE0000000000001', 'Unknown Previous Owner'),
      ('PRE0000000000002', 'Zoe Smith');      
COMMIT;

------------------------------------------------------------------------------
-- 4) Images - Insert some Images for the vehicles
------------------------------------------------------------------------------
BEGIN;
    INSERT INTO Images (VIN, imgLink)
    VALUES
      ('NEW0000000000001', 'https://example.com/images/NEW0000000000001_1.jpg'),
      ('NEW0000000000001', 'https://example.com/images/NEW0000000000001_2.jpg'),
      ('NEW0000000000002', 'https://example.com/images/NEW0000000000002.jpg'),
      ('PRE0000000000001', 'https://example.com/images/PRE0000000000001.jpg'),
      ('PRE0000000000002', 'https://example.com/images/PRE0000000000002.jpg'),
      ('TRA0000000000001', 'https://example.com/images/TRA0000000000001_1.jpg'),
      ('TRA0000000000001', 'https://example.com/images/TRA0000000000001_2.jpg');
COMMIT;

------------------------------------------------------------------------------
-- 5) TestDrive - Insert some test drives
------------------------------------------------------------------------------

BEGIN;
    INSERT INTO TestDrive (tid, VIN, testerEmail, salesPersonId, testDate, testTime, feedback)
    VALUES
      -- Alice 
      (1, 'NEW0000000000001', 'something@gmail.com', 300, '2023-08-01', '10:00', 'Nice handling'),
      -- Bob 
      (2, 'PRE0000000000001', 'somethingElse@gmail.com', 300, '2023-08-02', '13:30', 'Used but good price'),
      -- Carol
      (3, 'NEW0000000000002', 'yetSomethingElse@gmail.com', 301, '2023-08-03', '09:00', 'Smooth ride'),
      -- Zoe
      (4, 'PRE0000000000001', 'zoe@example.com', 300, '2023-08-15', '11:00', 'Decent used car');
COMMIT;

------------------------------------------------------------------------------
-- 6) Insert some Sales & Customers to test "Customer must have at least 1 purchase"
------------------------------------------------------------------------------
BEGIN;
    -- Insert a new Customer (pid=101) Alice (taken a test drive)
	INSERT INTO Customer (pid, testDriveId, driversLicence, streetNo, street, city, state, postcode, country)
	VALUES (102, 1, '12345178', '10', 'Smith St', 'Sydney', 'NSW', '2000', 'AU');
	
	-- Insert a Sale for same pid=101
	INSERT INTO Sale ( customerId, saleDate, saleVIN, tradedInVIN, salesPersonId,
	      discountPrice, basePrice, soldStatus
	  )
	 VALUES (102, '2023-09-01', 'NEW0000000000001', NULL, 300, 24000, 25000, FALSE);
COMMIT;

------------------------------------------------------------------------------
-- 7) Another sale, this one for Lewis(999) and with a traded-in vehicle
------------------------------------------------------------------------------
BEGIN;
    INSERT INTO PreownedVehicle (VIN, pre_owner)
        VALUES ('TRA0000000000001', 'Lewis Hamilton');
    INSERT INTO TradedInVehicle (VIN, mech_condition, body_condition, tradeInValue)
        VALUES
        ('TRA0000000000001', 'good', 'fair', 3000);
    INSERT INTO Customer (pid, testDriveId, driversLicence, streetNo, street, city, state, postcode, country)
    VALUES (999, 4, 'DL-Z999', '44', 'Alfred St', 'Adelaide', 'SA', '5000', 'AU');

    INSERT INTO Sale (customerId, saleDate, saleVIN, tradedInVIN, salesPersonId, discountPrice, basePrice, soldStatus)
    VALUES 
       (999, '2023-08-20', 'NEW0000000000002', 'TRA0000000000001', 301, 17000, 18000, FALSE);
COMMIT;

------------------------------------------------------------------------------
-- 8) Payment and BankLoan
------------------------------------------------------------------------------
BEGIN;
   INSERT INTO Payment (customerId, saleDate, paymentDate, amount, type)
   VALUES
     (999, '2023-08-20', '2023-08-20', 5000, 'cash'),
     (999, '2023-08-20', '2023-08-21', 19000, 'bank transfer');

   INSERT INTO BankFinancing (customerId, saleDate, bank, applicationDate, loanTerm, interestRate, loanValue, proofPresented)
   VALUES
     (999, '2023-08-20', 'ANZ', '2023-07-31', 24, 4.50, 19000, TRUE);

COMMIT;

------------------------------------------------------------------------------
-- 9) AfterMarketOption + IsAddedTo 
------------------------------------------------------------------------------
BEGIN;
    INSERT INTO AfterMarketOption (optionId, name, description)
    VALUES
      (1, 'Tinted Windows', 'Dark tints'),
      (2, 'Sunroof', 'Glass sunroof'),
      (3, 'Alloy Wheels', 'Nice alloy wheels'),
      (4, 'GPS', 'Navigation system'),
      (5, 'Premium Audio', 'Upgraded sound system'),
      (6, 'Leather Seats', 'Premium leather seats'),
      (7, 'Spoiler', 'A sporty spoiler'),
      (8, 'Heated Seats', 'Front seats heated'),
      (9, 'Extended Warranty', 'Longer coverage');
COMMIT;

-- Add 8 items to the same Sale
BEGIN;    
    INSERT INTO IsAddedTo (optionId, saleDate, customerId, VIN, cost)
    VALUES
      (1, '2023-09-01', 101, 'NEW0000000000001', 300),
      (2, '2023-09-01', 101, 'NEW0000000000001', 400),
      (3, '2023-09-01', 101, 'NEW0000000000001', 200),
      (4, '2023-09-01', 101, 'NEW0000000000001', 500),
      (5, '2023-09-01', 101, 'NEW0000000000001', 1000),
      (6, '2023-09-01', 101, 'NEW0000000000001', 450),
      (7, '2023-09-01', 101, 'NEW0000000000001', 600),
      (8, '2023-09-01', 101, 'NEW0000000000001', 750);
COMMIT;

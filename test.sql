-- TODO: test below; Add ON DELETE clauses where needed; INSERT statements with test data

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
    FOREIGN KEY (pid) REFERENCES Person(pid),
    grossSalary DECIMAL(10,2) CHECK (grossSalary > 0),
    commissionRate DECIMAL(5,2) CHECK (commissionRate > 0 AND commissionRate < 0.1)
    );

-- Customer (subtype of Person)
CREATE TABLE Customer (
    pid INT NOT NULL PRIMARY KEY,
    FOREIGN KEY (pid) REFERENCES Person(pid),
    driversLicence VARCHAR(50) NOT NULL UNIQUE, -- Didn't specify licence as PK as I believe the pk needs to be the same as the Person superclass
    apartmentNo VARCHAR(10),
    streetNo VARCHAR(10),
    CHECK (apartmentNo IS NOT NULL OR streetNo IS NOT NULL), -- I believe this is valid sql and will ensure either an apartmentNo or streetNo is provided
    street VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50) NOT NULL,
    postcode VARCHAR(20) NOT NULL,
    country VARCHAR(50) NOT NULL
);

-- Vehicle (supertype)
CREATE TABLE Vehicle (
    VIN VARCHAR(17) NOT NULL PRIMARY KEY,
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
    VIN VARCHAR(17) NOT NULL PRIMARY KEY,
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN)
);

-- PreownedVehicle (subtype of Vehicle)
CREATE TABLE PreownedVehicle (
    VIN VARCHAR(17) NOT NULL PRIMARY KEY,
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN),
    pre_owner VARCHAR(100) NOT NULL
);

-- TradedInVehicle (subtype of PreownedVehicle)
CREATE TABLE TradedInVehicle (
    VIN VARCHAR(17) NOT NULL PRIMARY KEY,
    FOREIGN KEY (VIN) REFERENCES PreownedVehicle(VIN),
    mech_condition VARCHAR(10) CHECK (mech_condition IN ('poor', 'fair', 'good', 'excellent')),
    body_condition VARCHAR(10) CHECK (body_condition IN ('poor', 'fair', 'good', 'excellent')),
    tradeInValue DECIMAL(8,0) CHECK (tradeInValue > 0)
);

-- ImageGallery (stores images for a given vehicle)
CREATE TABLE ImageGallery (
    VIN VARCHAR(17) NOT NULL,
    imgLink VARCHAR(255) NOT NULL,
    PRIMARY KEY (VIN, imgLink),
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN)
);

-- Sale 
CREATE TABLE Sale (
    customerId INT NOT NULL,
    saleDate DATE NOT NULL,
    saleVIN VARCHAR(17) NOT NULL,
    tradedInVIN VARCHAR(17),
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
    FOREIGN KEY (customerId, saleDate) REFERENCES Sale(customerId, saleDate)
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
    FOREIGN KEY (customerId, saleDate) REFERENCES Sale(customerId, saleDate)
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
    VIN VARCHAR(17) NOT NULL,
    cost DECIMAL(10,2) CHECK (cost > 0),
    PRIMARY KEY (optionId, saleDate, customerId, VIN),
    FOREIGN KEY (optionId) REFERENCES AfterMarketOption(optionId),
    FOREIGN KEY (customerId, saleDate, VIN) REFERENCES Sale(customerId, saleDate, saleVIN)
);

-- TestDrive
CREATE TABLE TestDrive (
    VIN VARCHAR(17) NOT NULL,
    customerId INT NOT NULL,
    salesPersonId INT NOT NULL,
    testDriveDate DATE NOT NULL,
    testDriveTime TIME NOT NULL,
    feedback VARCHAR(255),
    PRIMARY KEY (VIN, customerId, salesPersonId, testDriveDate),
    FOREIGN KEY (VIN) REFERENCES Vehicle(VIN),
    FOREIGN KEY (customerId) REFERENCES Customer(pid),
    FOREIGN KEY (salesPersonId) REFERENCES SalesPerson(pid)
);

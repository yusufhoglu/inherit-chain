// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract InheritanceManager {
    struct Beneficiary {
        address wallet;
        uint256 amount;  // share yerine direkt amount kullanacağız
    }

    struct Validator {
        address wallet;
        bool hasConfirmed;
    }

    struct Inheritance {
        bool isActive;
        bool isDead;
        uint256 confirmationCount;
        uint256 requiredConfirmations;
        mapping(uint256 => Beneficiary) beneficiaries;
        uint256 beneficiaryCount;
        mapping(uint256 => Validator) validators;
        uint256 validatorCount;
        uint256 totalShares;
        bool distributed;
        uint256 totalAmount;    // Toplam miras miktarı (wei cinsinden)
    }

    mapping(address => Inheritance) public inheritances;
    address[] public allInheritances;

    // Events
    event InheritanceCreated(address indexed owner);
    event BeneficiaryAdded(address indexed owner, address indexed beneficiary, uint256 amount);
    event ValidatorAdded(address indexed owner, address indexed validator);
    event DeathConfirmed(address indexed owner, address indexed validator, uint256 confirmationCount);
    event InheritanceDistributed(address indexed owner);

    // Modifiers
    modifier onlyActiveInheritance(address owner) {
        require(inheritances[owner].isActive, "Inheritance not found or inactive");
        _;
    }

    modifier onlyOwner() {
        require(!inheritances[msg.sender].isActive, "Inheritance already exists");
        _;
    }

    // Kontratın ETH alabilmesi için receive fonksiyonu ekliyoruz
    receive() external payable {}

    // Core functions
    function createInheritance() external onlyOwner {
        Inheritance storage newInheritance = inheritances[msg.sender];
        newInheritance.isActive = true;
        newInheritance.isDead = false;
        newInheritance.confirmationCount = 0;
        newInheritance.requiredConfirmations = 1;
        newInheritance.beneficiaryCount = 0;
        newInheritance.validatorCount = 0;
        newInheritance.totalShares = 0;
        newInheritance.distributed = false;
        newInheritance.totalAmount = 0;

        allInheritances.push(msg.sender);
        emit InheritanceCreated(msg.sender);
    }

    function addBeneficiary(address beneficiaryAddress, uint256 amount) 
        external 
        payable  // fonksiyonu payable yapıyoruz
        onlyActiveInheritance(msg.sender) 
    {
        require(beneficiaryAddress != address(0), "Invalid beneficiary address");
        require(amount > 0, "Amount must be greater than 0");
        require(msg.value == amount, "Must send exact amount for beneficiary");
        require(!inheritances[msg.sender].isDead, "Owner is dead");

        uint256 index = inheritances[msg.sender].beneficiaryCount;
        inheritances[msg.sender].beneficiaries[index] = Beneficiary(beneficiaryAddress, amount);
        inheritances[msg.sender].beneficiaryCount++;
        inheritances[msg.sender].totalAmount += amount;

        emit BeneficiaryAdded(msg.sender, beneficiaryAddress, amount);
    }

    function addValidator(address validatorAddress) 
        external 
        onlyActiveInheritance(msg.sender) 
    {
        require(validatorAddress != address(0), "Invalid validator address");
        require(!inheritances[msg.sender].isDead, "Owner is dead");
        
        // Check if validator is already added
        for(uint256 i = 0; i < inheritances[msg.sender].validatorCount; i++) {
            require(inheritances[msg.sender].validators[i].wallet != validatorAddress, "Validator already exists");
        }

        uint256 index = inheritances[msg.sender].validatorCount;
        inheritances[msg.sender].validators[index] = Validator(validatorAddress, false);
        inheritances[msg.sender].validatorCount++;
        
        if(inheritances[msg.sender].validatorCount < inheritances[msg.sender].requiredConfirmations) {
            inheritances[msg.sender].requiredConfirmations = inheritances[msg.sender].validatorCount;
        }

        emit ValidatorAdded(msg.sender, validatorAddress);
    }

    function confirmDeath(address owner) 
        external 
        onlyActiveInheritance(owner) 
    {
        require(!inheritances[owner].isDead, "Death already confirmed");
        require(inheritances[owner].beneficiaryCount > 0, "No beneficiaries added");
        
        uint256 validatorIndex;
        bool validatorFound = false;
        
        for(uint256 i = 0; i < inheritances[owner].validatorCount; i++) {
            if(inheritances[owner].validators[i].wallet == msg.sender) {
                validatorIndex = i;
                validatorFound = true;
                break;
            }
        }
        
        require(validatorFound, "Not a validator");
        require(!inheritances[owner].validators[validatorIndex].hasConfirmed, "Already confirmed");
        
        inheritances[owner].validators[validatorIndex].hasConfirmed = true;
        inheritances[owner].confirmationCount++;
        
        emit DeathConfirmed(owner, msg.sender, inheritances[owner].confirmationCount);

        if(inheritances[owner].confirmationCount >= inheritances[owner].requiredConfirmations) {
            inheritances[owner].isDead = true;
            distributeFunds(owner);
        }
    }

    function distributeFunds(address owner) internal {
        require(!inheritances[owner].distributed, "Already distributed");
        
        for(uint256 i = 0; i < inheritances[owner].beneficiaryCount; i++) {
            address payable beneficiary = payable(inheritances[owner].beneficiaries[i].wallet);
            uint256 amount = inheritances[owner].beneficiaries[i].amount;
            
            (bool success, ) = beneficiary.call{value: amount}("");
            require(success, "Transfer failed");
        }
        
        inheritances[owner].distributed = true;
        emit InheritanceDistributed(owner);
    }

    // Miras bakiyesini görüntüleme fonksiyonu
    function getInheritanceBalance() external view returns (uint256) {
        require(inheritances[msg.sender].isActive, "No active inheritance found");
        return address(this).balance;
    }

    // View functions
    function getBeneficiary(address owner, uint256 index) 
        external 
        view 
        returns (address wallet, uint256 amount) 
    {
        require(inheritances[owner].isActive, "Inheritance not found");
        require(index < inheritances[owner].beneficiaryCount, "Beneficiary not found");
        
        Beneficiary storage beneficiary = inheritances[owner].beneficiaries[index];
        return (beneficiary.wallet, beneficiary.amount);
    }

    function getBeneficiaryCount(address owner) 
        external 
        view 
        returns (uint256) 
    {
        return inheritances[owner].beneficiaryCount;
    }

    function getValidator(address owner, uint256 index) 
        external 
        view 
        returns (address) 
    {
        require(index < inheritances[owner].validatorCount, "Invalid index");
        return inheritances[owner].validators[index].wallet;
    }

    function getValidatorCount(address owner) 
        external 
        view 
        returns (uint256) 
    {
        return inheritances[owner].validatorCount;
    }

    function getValidatorConfirmation(address owner, uint256 index) 
        external 
        view 
        returns (bool) 
    {
        require(index < inheritances[owner].validatorCount, "Invalid index");
        return inheritances[owner].validators[index].hasConfirmed;
    }

    function getValidatorInheritances(address validator) 
        external 
        view 
        returns (address[] memory) 
    {
        uint256 count = 0;
        for (uint256 i = 0; i < allInheritances.length; i++) {
            address owner = allInheritances[i];
            if (isValidator(owner, validator)) {
                count++;
            }
        }
        
        address[] memory validatorInheritances = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allInheritances.length; i++) {
            address owner = allInheritances[i];
            if (isValidator(owner, validator)) {
                validatorInheritances[index] = owner;
                index++;
            }
        }
        
        return validatorInheritances;
    }

    function getValidatorIndex(address owner, address validator) 
        external 
        view 
        returns (uint256) 
    {
        require(inheritances[owner].isActive, "Inheritance not found");
        for (uint256 i = 0; i < inheritances[owner].validatorCount; i++) {
            if (inheritances[owner].validators[i].wallet == validator) {
                return i;
            }
        }
        revert("Validator not found");
    }

    function getInheritanceStatus(address owner) 
        external 
        view 
        returns (
            bool isActive,
            bool isDead,
            uint256 confirmationCount,
            uint256 requiredConfirmations,
            bool distributed
        ) 
    {
        Inheritance storage inheritance = inheritances[owner];
        return (
            inheritance.isActive,
            inheritance.isDead,
            inheritance.confirmationCount,
            inheritance.requiredConfirmations,
            inheritance.distributed
        );
    }

    function isValidator(address owner, address validator) 
        public 
        view 
        returns (bool) 
    {
        if (!inheritances[owner].isActive) {
            return false;
        }
        for (uint256 i = 0; i < inheritances[owner].validatorCount; i++) {
            if (inheritances[owner].validators[i].wallet == validator) {
                return true;
            }
        }
        return false;
    }

    // Miras miktarını gönderme fonksiyonu
    function sendInheritanceAmount() external payable {
        require(inheritances[msg.sender].isActive, "No active inheritance found");
        require(!inheritances[msg.sender].isDead, "Owner is dead");
        require(msg.value == inheritances[msg.sender].totalAmount, "Must send exact inheritance amount");
    }

    // Miras detaylarını görüntüleme fonksiyonu
    function getInheritanceDetails() external view returns (
        bool isActive,
        uint256 totalShares,
        uint256 totalAmount,
        uint256 currentBalance
    ) {
        Inheritance storage inheritance = inheritances[msg.sender];
        return (
            inheritance.isActive,
            inheritance.totalShares,
            inheritance.totalAmount,
            address(this).balance
        );
    }
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract InheritanceManager {
    struct Beneficiary {
        address wallet;
        uint256 share; // 100.00% = 10000
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
    }

    mapping(address => Inheritance) public inheritances;
    address[] public allInheritances;

    // Events
    event InheritanceCreated(address indexed owner);
    event BeneficiaryAdded(address indexed owner, address indexed beneficiary, uint256 share);
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

        allInheritances.push(msg.sender);
        emit InheritanceCreated(msg.sender);
    }

    function addBeneficiary(address beneficiaryAddress, uint256 share) 
        external 
        onlyActiveInheritance(msg.sender) 
    {
        require(beneficiaryAddress != address(0), "Invalid beneficiary address");
        require(share > 0 && share <= 10000, "Invalid share percentage");
        require(inheritances[msg.sender].totalShares + share <= 10000, "Total shares cannot exceed 100%");
        require(!inheritances[msg.sender].isDead, "Owner is dead");

        uint256 index = inheritances[msg.sender].beneficiaryCount;
        inheritances[msg.sender].beneficiaries[index] = Beneficiary(beneficiaryAddress, share);
        inheritances[msg.sender].beneficiaryCount++;
        inheritances[msg.sender].totalShares += share;

        emit BeneficiaryAdded(msg.sender, beneficiaryAddress, share);
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
        
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to distribute");
        
        for(uint256 i = 0; i < inheritances[owner].beneficiaryCount; i++) {
            address payable beneficiary = payable(inheritances[owner].beneficiaries[i].wallet);
            uint256 share = (balance * inheritances[owner].beneficiaries[i].share) / 10000;
            
            (bool success, ) = beneficiary.call{value: share}("");
            require(success, "Transfer failed");
        }
        
        inheritances[owner].distributed = true;
        emit InheritanceDistributed(owner);
    }

    // View functions
    function getBeneficiary(address owner, uint256 index) 
        external 
        view 
        returns (address wallet, uint256 share) 
    {
        require(index < inheritances[owner].beneficiaryCount, "Invalid index");
        Beneficiary storage beneficiary = inheritances[owner].beneficiaries[index];
        return (beneficiary.wallet, beneficiary.share);
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
} 
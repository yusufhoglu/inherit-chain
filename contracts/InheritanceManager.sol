// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract InheritanceManager is ReentrancyGuard, Ownable {
    struct Beneficiary {
        address wallet;
        uint256 share; // Yüzdelik pay (100 = %1)
        bool exists;
    }
    
    struct Validator {
        address wallet;
        bool hasConfirmed;
        bool exists;
    }
    
    struct Inheritance {
        address owner;
        Beneficiary[] beneficiaries;
        Validator[] validators;
        uint256 requiredConfirmations;
        bool isActive;
        bool isDead;
        uint256 confirmationCount;
    }
    
    mapping(address => Inheritance) public inheritances;
    address[] public allInheritances;
    
    event InheritanceCreated(address indexed owner, uint256 requiredConfirmations);
    event BeneficiaryAdded(address indexed owner, address indexed beneficiary, uint256 share);
    event ValidatorAdded(address indexed owner, address indexed validator);
    event DeathConfirmed(address indexed owner, address indexed validator);
    event InheritanceDistributed(address indexed owner);
    event InheritanceCancelled(address indexed owner);
    event InsufficientValidators(address indexed owner, uint256 currentValidators, uint256 requiredConfirmations);
    event RequiredConfirmationsUpdated(address indexed owner, uint256 newRequiredConfirmations);

    modifier onlyValidator(address _owner) {
        bool isValidator = false;
        for(uint i = 0; i < inheritances[_owner].validators.length; i++) {
            if(inheritances[_owner].validators[i].wallet == msg.sender) {
                isValidator = true;
                break;
            }
        }
        require(isValidator, "Caller is not a validator");
        _;
    }
    
    function createInheritance() public {
        require(!inheritances[msg.sender].isActive, "Inheritance already exists");
        
        Inheritance storage newInheritance = inheritances[msg.sender];
        newInheritance.owner = msg.sender;
        newInheritance.isActive = true;
        newInheritance.isDead = false;
        newInheritance.requiredConfirmations = 0;
        newInheritance.confirmationCount = 0;
        
        allInheritances.push(msg.sender);
        
        emit InheritanceCreated(msg.sender, 0);
    }
    
    function addBeneficiary(address _beneficiary, uint256 _share) external {
        require(inheritances[msg.sender].isActive, "Inheritance not created");
        require(!inheritances[msg.sender].isDead, "Owner is declared dead");
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_share > 0, "Share must be greater than 0");
        
        inheritances[msg.sender].beneficiaries.push(Beneficiary({
            wallet: _beneficiary,
            share: _share,
            exists: true
        }));
        
        emit BeneficiaryAdded(msg.sender, _beneficiary, _share);
    }
    
    function addValidator(address _validator) public {
        require(inheritances[msg.sender].isActive, "Inheritance not created");
        require(_validator != address(0), "Invalid validator address");
        require(_validator != msg.sender, "Owner cannot be validator");
        
        // Aynı doğrulayıcının tekrar eklenmesini engelle
        for(uint i = 0; i < inheritances[msg.sender].validators.length; i++) {
            require(inheritances[msg.sender].validators[i].wallet != _validator, "Validator already exists");
        }
        
        Validator memory newValidator = Validator({
            wallet: _validator,
            hasConfirmed: false,
            exists: true
        });
        
        inheritances[msg.sender].validators.push(newValidator);
        
        // Gerekli onay sayısını otomatik güncelle
        inheritances[msg.sender].requiredConfirmations = inheritances[msg.sender].validators.length;
        
        emit ValidatorAdded(msg.sender, _validator);
        emit RequiredConfirmationsUpdated(msg.sender, inheritances[msg.sender].validators.length);
    }
    
    function confirmDeath(address _owner) external onlyValidator(_owner) nonReentrant {
        require(inheritances[_owner].isActive, "Inheritance not created");
        require(!inheritances[_owner].isDead, "Death already confirmed");
        
        uint256 confirmations = 0;
        for(uint i = 0; i < inheritances[_owner].validators.length; i++) {
            if(inheritances[_owner].validators[i].wallet == msg.sender) {
                require(!inheritances[_owner].validators[i].hasConfirmed, "Already confirmed");
                inheritances[_owner].validators[i].hasConfirmed = true;
            }
            if(inheritances[_owner].validators[i].hasConfirmed) {
                confirmations++;
            }
        }
        
        if(confirmations >= inheritances[_owner].requiredConfirmations) {
            inheritances[_owner].isDead = true;
            distributeInheritance(_owner);
        }
        
        emit DeathConfirmed(_owner, msg.sender);
    }
    
    function distributeInheritance(address _owner) private {
        uint256 totalBalance = address(this).balance;
        uint256 totalShares = 0;
        
        for(uint i = 0; i < inheritances[_owner].beneficiaries.length; i++) {
            totalShares += inheritances[_owner].beneficiaries[i].share;
        }
        
        for(uint i = 0; i < inheritances[_owner].beneficiaries.length; i++) {
            Beneficiary memory beneficiary = inheritances[_owner].beneficiaries[i];
            uint256 amount = (totalBalance * beneficiary.share) / totalShares;
            payable(beneficiary.wallet).transfer(amount);
        }
        
        emit InheritanceDistributed(_owner);
    }

    function cancelInheritance() external {
        require(inheritances[msg.sender].isActive, "Inheritance not found");
        require(inheritances[msg.sender].owner == msg.sender, "Not inheritance owner");
        require(!inheritances[msg.sender].isDead, "Cannot cancel after death confirmation");
        
        // Diziyi güncelle
        for (uint i = 0; i < allInheritances.length; i++) {
            if (allInheritances[i] == msg.sender) {
                allInheritances[i] = allInheritances[allInheritances.length - 1];
                allInheritances.pop();
                break;
            }
        }
        
        delete inheritances[msg.sender];
        
        emit InheritanceCancelled(msg.sender);
    }
    
    receive() external payable {}

    // Varis sayısını getir
    function getBeneficiaryCount(address owner) public view returns (uint256) {
        return inheritances[owner].beneficiaries.length;
    }

    // Belirli bir varisi getir
    function getBeneficiary(address owner, uint256 index) public view returns (address wallet, uint256 share) {
        require(index < inheritances[owner].beneficiaries.length, "Invalid index");
        Beneficiary memory beneficiary = inheritances[owner].beneficiaries[index];
        return (beneficiary.wallet, beneficiary.share);
    }

    // Doğrulayıcı sayısını getir
    function getValidatorCount(address owner) public view returns (uint256) {
        return inheritances[owner].validators.length;
    }

    // Belirli bir doğrulayıcıyı getir
    function getValidator(address owner, uint256 index) public view returns (address) {
        require(index < inheritances[owner].validators.length, "Invalid index");
        return inheritances[owner].validators[index].wallet;
    }

    // Doğrulayıcının onay durumunu getir
    function getValidatorConfirmation(address owner, uint256 index) public view returns (bool) {
        require(index < inheritances[owner].validators.length, "Invalid index");
        return inheritances[owner].validators[index].hasConfirmed;
    }

    function updateRequiredConfirmations(uint256 _newRequiredConfirmations) public {
        require(inheritances[msg.sender].isActive, "Inheritance not created");
        require(_newRequiredConfirmations > 0, "Required confirmations must be greater than 0");
        require(_newRequiredConfirmations <= inheritances[msg.sender].validators.length, "Required confirmations cannot exceed validator count");
        
        inheritances[msg.sender].requiredConfirmations = _newRequiredConfirmations;
        emit RequiredConfirmationsUpdated(msg.sender, _newRequiredConfirmations);
    }

    // Bir doğrulayıcının hangi miras planlarında doğrulayıcı olduğunu getiren fonksiyon
    function getValidatorInheritances(address validator) public view returns (address[] memory) {
        uint count = 0;
        // Önce sayıyı bulalım
        for (uint i = 0; i < allInheritances.length; i++) {
            address owner = allInheritances[i];
            if (isValidator(owner, validator)) {
                count++;
            }
        }
        
        // Şimdi adresleri toplayalım
        address[] memory validatorInheritances = new address[](count);
        uint index = 0;
        for (uint i = 0; i < allInheritances.length; i++) {
            address owner = allInheritances[i];
            if (isValidator(owner, validator)) {
                validatorInheritances[index] = owner;
                index++;
            }
        }
        
        return validatorInheritances;
    }

    // Bir doğrulayıcının belirli bir miras planındaki index'ini döndüren yardımcı fonksiyon
    function getValidatorIndex(address owner, address validator) public view returns (uint) {
        require(inheritances[owner].isActive, "Inheritance not found");
        for (uint i = 0; i < inheritances[owner].validators.length; i++) {
            if (inheritances[owner].validators[i].wallet == validator) {
                return i;
            }
        }
        revert("Validator not found");
    }

    // Bir adresin belirli bir miras planında doğrulayıcı olup olmadığını kontrol eden yardımcı fonksiyon
    function isValidator(address owner, address validator) public view returns (bool) {
        if (!inheritances[owner].isActive) {
            return false;
        }
        for (uint i = 0; i < inheritances[owner].validators.length; i++) {
            if (inheritances[owner].validators[i].wallet == validator) {
                return true;
            }
        }
        return false;
    }
} 
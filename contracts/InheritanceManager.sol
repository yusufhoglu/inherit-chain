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
    }
    
    mapping(address => Inheritance) public inheritances;
    
    event InheritanceCreated(address indexed owner);
    event BeneficiaryAdded(address indexed owner, address indexed beneficiary, uint256 share);
    event ValidatorAdded(address indexed owner, address indexed validator);
    event DeathConfirmed(address indexed owner, address indexed validator);
    event InheritanceDistributed(address indexed owner);
    event InheritanceCancelled(address indexed owner);

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
    
    function createInheritance(uint256 _requiredConfirmations) external {
        require(!inheritances[msg.sender].isActive, "Inheritance already exists");
        require(_requiredConfirmations > 0, "Required confirmations must be greater than 0");
        
        inheritances[msg.sender].owner = msg.sender;
        inheritances[msg.sender].requiredConfirmations = _requiredConfirmations;
        inheritances[msg.sender].isActive = true;
        
        emit InheritanceCreated(msg.sender);
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
    
    function addValidator(address _validator) external {
        require(inheritances[msg.sender].isActive, "Inheritance not created");
        require(!inheritances[msg.sender].isDead, "Owner is declared dead");
        require(_validator != address(0), "Invalid validator address");
        
        inheritances[msg.sender].validators.push(Validator({
            wallet: _validator,
            hasConfirmed: false,
            exists: true
        }));
        
        emit ValidatorAdded(msg.sender, _validator);
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
} 
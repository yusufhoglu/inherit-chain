const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("InheritanceManager", function () {
    let inheritanceManager;
    let owner;
    let beneficiary1;
    let beneficiary2;
    let validator1;
    let validator2;
    
    beforeEach(async function () {
        [owner, beneficiary1, beneficiary2, validator1, validator2] = await ethers.getSigners();
        
        const InheritanceManager = await ethers.getContractFactory("InheritanceManager");
        inheritanceManager = await InheritanceManager.deploy();
        await inheritanceManager.deployed();
    });
    
    it("Should create inheritance successfully", async function () {
        await inheritanceManager.createInheritance(2);
        const inheritance = await inheritanceManager.inheritances(owner.address);
        expect(inheritance.isActive).to.equal(true);
        expect(inheritance.requiredConfirmations).to.equal(2);
    });
    
    it("Should add beneficiary successfully", async function () {
        await inheritanceManager.createInheritance(2);
        await inheritanceManager.addBeneficiary(beneficiary1.address, 5000);
        await inheritanceManager.addBeneficiary(beneficiary2.address, 5000);
    });
    
    it("Should add validator successfully", async function () {
        await inheritanceManager.createInheritance(2);
        await inheritanceManager.addValidator(validator1.address);
        await inheritanceManager.addValidator(validator2.address);
    });
    
    it("Should distribute inheritance after death confirmation", async function () {
        await inheritanceManager.createInheritance(2);
        await inheritanceManager.addBeneficiary(beneficiary1.address, 5000);
        await inheritanceManager.addBeneficiary(beneficiary2.address, 5000);
        await inheritanceManager.addValidator(validator1.address);
        await inheritanceManager.addValidator(validator2.address);
        
        // Test için ETH gönder
        await owner.sendTransaction({
            to: inheritanceManager.address,
            value: ethers.utils.parseEther("10.0")
        });
        
        await inheritanceManager.connect(validator1).confirmDeath(owner.address);
        await inheritanceManager.connect(validator2).confirmDeath(owner.address);
        
        const inheritance = await inheritanceManager.inheritances(owner.address);
        expect(inheritance.isDead).to.equal(true);
    });
}); 
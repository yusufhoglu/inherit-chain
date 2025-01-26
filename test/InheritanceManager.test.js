const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("InheritanceManager", function () {
    let InheritanceManager;
    let inheritanceManager;
    let owner;
    let beneficiary1;
    let beneficiary2;
    let validator1;
    let validator2;

    beforeEach(async function () {
        [owner, beneficiary1, beneficiary2, validator1, validator2] = await ethers.getSigners();
        
        InheritanceManager = await ethers.getContractFactory("InheritanceManager");
        inheritanceManager = await InheritanceManager.deploy();
        await inheritanceManager.deployed();
    });

    describe("Inheritance Creation", function () {
        it("Should create a new inheritance plan", async function () {
            await inheritanceManager.createInheritance();
            const inheritance = await inheritanceManager.inheritances(owner.address);
            expect(inheritance.isActive).to.equal(true);
        });

        it("Should not allow creating multiple inheritance plans", async function () {
            await inheritanceManager.createInheritance();
            await expect(inheritanceManager.createInheritance())
                .to.be.revertedWith("Inheritance already exists");
        });
    });

    describe("Beneficiary Management", function () {
        beforeEach(async function () {
            await inheritanceManager.createInheritance();
        });

        it("Should add a beneficiary", async function () {
            await inheritanceManager.addBeneficiary(beneficiary1.address, 5000);
            const [address, share] = await inheritanceManager.getBeneficiary(owner.address, 0);
            expect(address).to.equal(beneficiary1.address);
            expect(share).to.equal(5000);
        });

        it("Should not allow adding beneficiaries with invalid shares", async function () {
            await expect(inheritanceManager.addBeneficiary(beneficiary1.address, 0))
                .to.be.revertedWith("Invalid share percentage");
            await expect(inheritanceManager.addBeneficiary(beneficiary1.address, 10001))
                .to.be.revertedWith("Invalid share percentage");
        });

        it("Should not exceed 100% total shares", async function () {
            await inheritanceManager.addBeneficiary(beneficiary1.address, 6000);
            await inheritanceManager.addBeneficiary(beneficiary2.address, 4000);
            await expect(inheritanceManager.addBeneficiary(owner.address, 1))
                .to.be.revertedWith("Total shares cannot exceed 100%");
        });
    });

    describe("Validator Management", function () {
        beforeEach(async function () {
            await inheritanceManager.createInheritance();
        });

        it("Should add a validator", async function () {
            await inheritanceManager.addValidator(validator1.address);
            const validatorAddress = await inheritanceManager.getValidator(owner.address, 0);
            expect(validatorAddress).to.equal(validator1.address);
        });

        it("Should not add duplicate validators", async function () {
            await inheritanceManager.addValidator(validator1.address);
            await expect(inheritanceManager.addValidator(validator1.address))
                .to.be.revertedWith("Validator already exists");
        });
    });

    describe("Death Confirmation", function () {
        beforeEach(async function () {
            await inheritanceManager.createInheritance();
            await inheritanceManager.addBeneficiary(beneficiary1.address, 5000);
            await inheritanceManager.addBeneficiary(beneficiary2.address, 5000);
            await inheritanceManager.addValidator(validator1.address);
            await inheritanceManager.addValidator(validator2.address);

            // Test için ETH gönderiyoruz
            await owner.sendTransaction({
                to: inheritanceManager.address,
                value: ethers.utils.parseEther("10.0")
            });
        });

        it("Should allow validators to confirm death", async function () {
            await inheritanceManager.connect(validator1).confirmDeath(owner.address);
            const confirmation = await inheritanceManager.getValidatorConfirmation(owner.address, 0);
            expect(confirmation).to.equal(true);
        });

        it("Should not allow non-validators to confirm death", async function () {
            await expect(inheritanceManager.connect(beneficiary1).confirmDeath(owner.address))
                .to.be.revertedWith("Not a validator");
        });

        it("Should not allow double confirmation", async function () {
            // İlk onay
            await inheritanceManager.connect(validator1).confirmDeath(owner.address);
            
            // İkinci onay denemesi - ölüm zaten onaylandığı için hata vermeli
            await expect(inheritanceManager.connect(validator1).confirmDeath(owner.address))
                .to.be.revertedWith("Death already confirmed");
        });

        it("Should distribute funds after required confirmations", async function () {
            const initialBalance1 = await ethers.provider.getBalance(beneficiary1.address);
            await inheritanceManager.connect(validator1).confirmDeath(owner.address);
            const finalBalance1 = await ethers.provider.getBalance(beneficiary1.address);
            expect(finalBalance1.gt(initialBalance1)).to.be.true;
        });
    });

    describe("Fund Distribution", function () {
        beforeEach(async function () {
            await inheritanceManager.createInheritance();
            await inheritanceManager.addBeneficiary(beneficiary1.address, 5000);
            await inheritanceManager.addBeneficiary(beneficiary2.address, 5000);
            await inheritanceManager.addValidator(validator1.address);
            
            // ETH'yi kontrata gönderiyoruz, owner'a değil
            await owner.sendTransaction({
                to: inheritanceManager.address,
                value: ethers.utils.parseEther("10.0")
            });
        });

        it("Should distribute funds when all required confirmations are received", async function () {
            const initialBalance1 = await ethers.provider.getBalance(beneficiary1.address);
            const initialBalance2 = await ethers.provider.getBalance(beneficiary2.address);

            await inheritanceManager.connect(validator1).confirmDeath(owner.address);

            const finalBalance1 = await ethers.provider.getBalance(beneficiary1.address);
            const finalBalance2 = await ethers.provider.getBalance(beneficiary2.address);

            expect(finalBalance1.gt(initialBalance1)).to.be.true;
            expect(finalBalance2.gt(initialBalance2)).to.be.true;
        });
    });
}); 
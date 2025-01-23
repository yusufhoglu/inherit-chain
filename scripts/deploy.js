const hre = require("hardhat");

async function main() {
  // Kontrat fabrikasını al
  const InheritanceManager = await hre.ethers.getContractFactory("InheritanceManager");
  
  // Kontratı deploy et
  const inheritanceManager = await InheritanceManager.deploy();

  // Deploy işleminin tamamlanmasını bekle
  await inheritanceManager.deployed();

  console.log("InheritanceManager deployed to:", inheritanceManager.address);
}
// Script'i çalıştır ve hataları yakala
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 
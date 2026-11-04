// scripts/deploy.js
async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Deploy MultiSig Treasury first
  const owners = [
    deployer.address,
    "0xOwner2Address", // Replace with actual addresses
    "0xOwner3Address",
    "0xOwner4Address", 
    "0xOwner5Address"
  ];
  const required = 3;
  
  const MultiSigTreasury = await ethers.getContractFactory("MultiSigTreasury");
  const multiSig = await MultiSigTreasury.deploy(owners, required);
  await multiSig.deployed();
  console.log("MultiSigTreasury deployed to:", multiSig.address);

  // Deploy Reward Distributor
  const SocialRewardDistributor = await ethers.getContractFactory("SocialRewardDistributor");
  const rewardDistributor = await SocialRewardDistributor.deploy();
  await rewardDistributor.deployed();
  console.log("SocialRewardDistributor deployed to:", rewardDistributor.address);

  // Deploy Main Token
  const MangoSocialToken = await ethers.getContractFactory("MangoSocialToken");
  const mangoToken = await MangoSocialToken.deploy(multiSig.address, rewardDistributor.address);
  await mangoToken.deployed();
  console.log("MangoSocialToken deployed to:", mangoToken.address);

  // Transfer reward distributor ownership to MultiSig
  await rewardDistributor.transferOwnership(multiSig.address);
  console.log("Reward distributor ownership transferred to MultiSig");

  // Save deployment info
  const deploymentInfo = {
    network: network.name,
    timestamp: new Date().toISOString(),
    contracts: {
      multiSigTreasury: multiSig.address,
      rewardDistributor: rewardDistributor.address,
      mangoToken: mangoToken.address,
    },
    owners: owners,
    requiredSignatures: required,
  };

  fs.writeFileSync('deployment.json', JSON.stringify(deploymentInfo, null, 2));
  console.log("Deployment info saved to deployment.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
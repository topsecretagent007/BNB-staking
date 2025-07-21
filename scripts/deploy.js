const fs = require('fs');
async function main() {
  let deployOutput = "";

  console.log("RPC Passed. ✅");

  const lpStaking = await ethers.deployContract("LPStaking");
  const treasury =  await ethers.deployContract("Treasury");
  const vault = await ethers.deployContract("Vault");

  console.log("LP Staking Contract address:", await lpStaking.getAddress());
  console.log("Treasury Contract address:", await treasury.getAddress());
  console.log("Tax Vault Contract address:", await vault.getAddress());


  const dripToken = await ethers.deployContract("DripToken", [initialMint]);
  await dripToken.waitForDeployment();
  const dripTokenAddr = await dripToken.getAddress();
  console.log("DripToken Deployed. ✅");
  deployOutput += "DRIP_CONTRACT=".concat(dripTokenAddr).concat("\n");

  const lpToken = await ethers.deployContract("DRIP_BNBLPToken");
  await lpToken.waitForDeployment();
  console.log("LpToken Deployed. ✅");
  const lpTokenAddr = await lpToken.getAddress();
  deployOutput += "LPTOKEN_CONTRACT=".concat(lpTokenAddr).concat("\n");

  const vault = await ethers.deployContract("Vault", [
    await dripToken.getAddress(),
  ]);
  await vault.waitForDeployment();
  const vaultAddr = await vault.getAddress();
  console.log("Vault Deployed. ✅");
  deployOutput += "VAULT_CONTRACT=".concat(vaultAddr).concat("\n");

  const treasury = await ethers.deployContract("Treasury", [
    dripTokenAddr,
    vaultAddr,
  ]);
  await treasury.waitForDeployment();
  const treasuryAddr = await treasury.getAddress();
  console.log("Treasury Deployed. ✅");
  deployOutput += "TREASURY_CONTRACT=".concat(treasuryAddr).concat("\n");

  const dripStaking = await ethers.deployContract("DripStaking", [
    dripTokenAddr,
    lpTokenAddr,
  ]);
  await dripStaking.waitForDeployment();
  const stakingAddr = await dripStaking.getAddress();
  console.log("Staking Contract Deployed. ✅");
  deployOutput += "STAKING_CONTRACT=".concat(stakingAddr).concat("\n");

  fs.writeFileSync("contracts.env",deployOutput);

  await dripToken.excludeAccount(stakingAddr);

  await dripToken.excludeAccount(treasuryAddr);
  
  await dripToken.excludeAccount(vaultAddr);

  await vault.addAddressToWhitelist(treasuryAddr);

  await dripToken.addAddressToWhitelist(stakingAddr);

  await dripToken.setVaultAddress(vaultAddr);

  await dripToken.addAddressToWhitelist(signers[0].address);

  await dripToken.mint(vaultAddr, initialTaxAmount);

  await dripStaking.updateTreasury(treasuryAddr);

  await dripStaking.updateDripPerBlock(initialDripPerBlock);

  await treasury.setStakingContract(stakingAddr);

  return {
    signers,
    initialDripPerBlock,
    dripToken,
    vault,
    lpToken,
    treasury,
    dripStaking,
  };
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
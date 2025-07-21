const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  helpers,
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");

const stakingFixture = async () => {
  const signers = await ethers.getSigners();

  const initialMint = 100000;
  const initialTaxAmount = 1000000000000000000n;
  const initialDripPerBlock = 35000000000000000n;

  const dripToken = await ethers.deployContract("DripToken", [initialMint]);
  await dripToken.waitForDeployment();

  const lpToken = await ethers.deployContract("DRIP_BNBLPToken");
  await lpToken.waitForDeployment();

  const vault = await ethers.deployContract("Vault", [
    await dripToken.getAddress(),
  ]);
  await vault.waitForDeployment();

  const dripTokenAddr = await dripToken.getAddress();
  const vaultAddr = await vault.getAddress();
  const lpTokenAddr = await lpToken.getAddress();

  const treasury = await ethers.deployContract("Treasury", [
    dripTokenAddr,
    vaultAddr,
  ]);

  const dripStaking = await ethers.deployContract("DripStaking", [
    dripTokenAddr,
    lpTokenAddr,
  ]);

  const treasuryAddr = await treasury.getAddress();
  const stakingAddr = await dripStaking.getAddress();

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
};

describe("Staking Contract Testing", async () => {
  let tokens = {};
  let stakedTime;
  let lockPeriod;
  describe("Should Deploy and Initialize Correctly", async () => {
    it("Vault Address is Set Correctly", async () => {
      tokens = {
        signers,
        initialDripPerBlock,
        dripToken,
        vault,
        lpToken,
        treasury,
        dripStaking,
      } = await loadFixture(stakingFixture);
      expect(await dripToken.vaultAddress()).to.equal(await vault.getAddress());
    });

    it("DripPerBlock Amount is Set Correctly", async () => {
      expect(await dripStaking.dripPerBlock()).to.equal(initialDripPerBlock);
    });

    it("Treasury Contract Address is Set Correctly", async () => {
      expect(await dripStaking.TREASURY()).to.equal(
        await treasury.getAddress()
      );
    });

    it("Staking Contract Address is Set Correctly in Treasury Contract", async () => {
      expect(await treasury.stakingContract()).to.equal(
        await dripStaking.getAddress()
      );
    });
  });

  describe("Staking Function Test", async () => {
    const testAmount = 1000000000000000000000000n;
    lockPeriod = 86400 * 70;
    it("Should Stake LP", async () => {
      const { signers, dripStaking } = tokens;

      lpToken.approve(await dripStaking.getAddress(), testAmount);
      // Stake LP Tokens
      await dripStaking.connect(signers[0]).stake(testAmount, lockPeriod);

    });

    it("Staked Count is Exactly One", async () => {
      expect(await dripStaking.currentStakedId(signers[0])).to.equal(1);
    });
    
    it("Staked User Info is Stored Correctly", async () => {
      const {
        amount,
        rewardDebt,
        boostMultiplier,
        lockStartTime,
        lockEndTime,
      } = await dripStaking.userInfo(signers[0].address, 0);
      stakedTime = await time.latest();
      const multiplier =
        parseInt((Number(await dripStaking.BOOST_WEIGHT())  * lockPeriod) /
          (365 * 86400)) +
        1e12;

      expect(amount).to.equal(testAmount);

      expect(lockStartTime).to.equal(stakedTime);
  
      expect(lockEndTime).to.equal(stakedTime + lockPeriod);
  
      expect(boostMultiplier).to.equal(BigInt(multiplier));
  
      expect(rewardDebt).to.equal(0);
    });

  });

  describe("Claim Reward Function Test", async () => {
    it("Pending Reward Calculated Correctly", async () => {
      const {dripStaking, signers} = tokens;
      const {
        amount,
        rewardDebt,
        boostMultiplier,
        
      } = await dripStaking.userInfo(signers[0].address, 0);

      await time.advanceBlock(1000);

      const pendingDrip = await dripStaking.pendingDrip(signers[0].address, 0)

      let  apShare = await dripStaking.accDripPerShare();
      const dripPerBlock = await dripStaking.dripPerBlock();
      const boostedShare = await dripStaking.totalBoostedShare();
      const lastBlock = await dripStaking.lastRewardBlock();
      const dripPrecision = await dripStaking.ACC_DRIP_PRECISION();
      const boostPrecision = await dripStaking.BOOST_PRECISION();

      apShare += dripPerBlock * (BigInt(await time.latestBlock()) - lastBlock) * dripPrecision / boostedShare;

      const boostedAmount = amount * boostMultiplier / boostPrecision;
      const calculatedPending = boostedAmount * apShare / dripPrecision - rewardDebt;
     
      expect(pendingDrip).to.equal(calculatedPending);

    })

    it("Claim Amount is Calculated Correctly", async () => {
      const {
        dripStaking, 
        dripToken,
        signers
      } = tokens;

      await time.advanceBlock(1000);

      const beforeAmount = (await dripToken.balanceOf(signers[0].address));
     
      const pendingDrip = await dripStaking.pendingDrip(signers[0].address, 0);
      await dripStaking.claim(0);
      const afterAmount = (await dripToken.balanceOf(signers[0].address));
  
      expect(pendingDrip).to.equal(afterAmount - beforeAmount);
    })
  });


  describe("Withdraw Function Test", async () => {
    it("Withdraw Drip Claim Amount is Calculated Correctly", async () => {
      const {
        dripStaking, 
        dripToken,
        lpToken,
        signers
      } = tokens;

      const {
        amount,
      } = await dripStaking.userInfo(signers[0].address, 0);

      await time.advanceBlock(2000);
      await time.increase(lockPeriod);

      const beforeAmount = (await dripToken.balanceOf(signers[0].address));
      const berforeLpAmount = await lpToken.balanceOf(signers[0].address)
     
      const pendingDrip = await dripStaking.pendingDrip(signers[0].address, 0);
      await dripStaking.withdraw(0);
      const afterAmount = (await dripToken.balanceOf(signers[0].address));
      const afterLpAmount = await lpToken.balanceOf(signers[0].address)
  
      expect(pendingDrip).to.equal(afterAmount - beforeAmount);

      expect(amount).to.equal(afterLpAmount - berforeLpAmount);

    })
  });
});


describe("Treasury Contract Testing", async () => {
  let tokens = {};
  let stakedTime;
  let lockPeriod;
  describe("Should Deploy and Initialize Correctly", async () => {
    it("Vault Address is Set Correctly", async () => {
      tokens = {
        signers,
        initialDripPerBlock,
        dripToken,
        vault,
        lpToken,
        treasury,
        dripStaking,
      } = await loadFixture(stakingFixture);
      expect(await dripToken.vaultAddress()).to.equal(await vault.getAddress());
    });

    it("DripPerBlock Amount is Set Correctly", async () => {
      expect(await dripStaking.dripPerBlock()).to.equal(initialDripPerBlock);
    });

    it("Treasury Contract Address is Set Correctly", async () => {
      expect(await dripStaking.TREASURY()).to.equal(
        await treasury.getAddress()
      );
    });

    it("Staking Contract Address is Set Correctly in Treasury Contract", async () => {
      expect(await treasury.stakingContract()).to.equal(
        await dripStaking.getAddress()
      );
    });
  });

  describe("Staking Function Test", async () => {
    const testAmount = 1000000000000000000000000n;
    lockPeriod = 86400 * 70;
    
    it("Should Stake LP", async () => {
      const { signers, dripStaking } = tokens;

      lpToken.approve(await dripStaking.getAddress(), testAmount);
      // Stake LP Tokens
      await dripStaking.connect(signers[0]).stake(testAmount, lockPeriod);

    });

    it("Staked Count is Exactly One", async () => {
      expect(await dripStaking.currentStakedId(signers[0])).to.equal(1);
    });
    
    it("Staked User Info is Stored Correctly", async () => {
      const {
        amount,
        rewardDebt,
        boostMultiplier,
        lockStartTime,
        lockEndTime,
      } = await dripStaking.userInfo(signers[0].address, 0);
      
      stakedTime = await time.latest();
      const multiplier =
        parseInt((Number(await dripStaking.BOOST_WEIGHT())  * lockPeriod) /
          (365 * 86400)) +
        1e12;

      expect(amount).to.equal(testAmount);

      expect(lockStartTime).to.equal(stakedTime);
  
      expect(lockEndTime).to.equal(stakedTime + lockPeriod);
  
      expect(boostMultiplier).to.equal(BigInt(multiplier));
  
      expect(rewardDebt).to.equal(0);
    });

  });
  
  describe("Treasury Function Test", async () => {
    it("When Claim, Mint Amount is Correct!", async () => {
      const {
        dripStaking, 
        dripToken,
        signers
      } = tokens;

      await time.advanceBlock(1000);

      const beforeAmount = await dripToken.totalSupply();
     
      const lsMintTime = await dripStaking.lastMintTime();
      const totalSupplyYear = await dripStaking.totalSupplyYear();

      const calculatedMintAmount = totalSupplyYear / 20n * (BigInt(await time.latest()) - lsMintTime + 1n) / (365n * 86400n);

      await dripStaking.claim(0);
      const afterAmount = await dripToken.totalSupply();
  
      expect(calculatedMintAmount).to.equal(afterAmount - beforeAmount);
    });

    it("When Claim, Treasury Payout Amount(1% Daily) is Correct!", async () => {
      const {
        dripStaking, 
        dripToken,
        vault,
        treasury,
        signers
      } = tokens;

      const testTaxAmount = 100000000000000000000n;

      await dripToken.mint(await vault.getAddress(), testTaxAmount);

      await time.advanceBlock(1000);

      const beforeAmount = await dripToken.balanceOf(await dripStaking.getAddress());
      const beforeVaultAmount = await dripToken.balanceOf(await vault.getAddress());
      const beforeUserAmount = await dripToken.balanceOf(signers[0].address);
     
      const lsMintTime = await dripStaking.lastMintTime();
      const totalSupplyYear = await dripStaking.totalSupplyYear();
      const calculatedMintAmount = totalSupplyYear / 20n * (BigInt(await time.latest() + 1) - lsMintTime) / (365n * 86400n);

      const beforeTreasuryAmount = await dripToken.balanceOf(await treasury.getAddress());

      const lsPayoutTime = await treasury.lastPayoutTime();
      const payoutRate = await treasury.PAYOUT_RATE();

      let payoutAmount;
      if (lsPayoutTime == 0n) {
        payoutAmount = (beforeTreasuryAmount + beforeVaultAmount / 10n) * payoutRate / 100n;
      } else {
        payoutAmount = (beforeTreasuryAmount + beforeVaultAmount / 10n) * payoutRate / 100n / 86400n * (BigInt(await time.latest() + 1) - lsPayoutTime);
      }

      await dripStaking.claim(0);

      const afterAmount = await dripToken.balanceOf(await dripStaking.getAddress());
      const afterUserAmount = await dripToken.balanceOf(signers[0].address);

      const transferedAmount = afterAmount - beforeAmount - calculatedMintAmount  + (afterUserAmount - beforeUserAmount);
  
      expect(transferedAmount).to.equal(payoutAmount);
    });
  });
});

describe("Vault Function Testing", async () => {
  it("Tax Transfer Amount Checked", async () => {
    tokens = {
      signers,
      initialDripPerBlock,
      dripToken,
      vault,
      lpToken,
      treasury,
      dripStaking,
    } = await loadFixture(stakingFixture);

    const transferAmount = 100000000000000000000n;

    const beforeVaultAmount = await dripToken.balanceOf(await vault.getAddress());
    await dripToken.transfer(signers[1].address, transferAmount);
    const afterVaultAmount = await dripToken.balanceOf(await vault.getAddress());

    expect(afterVaultAmount - beforeVaultAmount).to.equal(transferAmount * 10n/100n);
  })
})

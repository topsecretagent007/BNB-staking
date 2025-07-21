// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
import "hardhat/console.sol";

import "./interfaces/IBEP20.sol";
import "./interfaces/IVault.sol";


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

contract Treasury is Ownable {
    using SafeMath for uint256;

    IBEP20 internal DRIP;  // address of the BEP20 token traded on this contract
    IVault internal VAULT; // address of the Vault contract 

    address public stakingContract;
    address public DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public lastTaxTransferTime;
    uint256 public lastPayoutTime;

    uint256 public COOL_DOWN = 5 minutes;
    uint256 public PAYOUT_RATE = 1;


    // We receive Drip token on this vault
    constructor(address _dripToken, address _vault) Ownable(_msgSender()) {
        /// Mainnet
        // DRIP = IBEP20(0x20f663CEa80FaCE82ACDFA3aAE6862d246cE0333);
        // VAULT = IVault(0xBFF8a1F9B5165B787a00659216D7313354D25472);
        
        /// Testnet
        // DRIP = IBEP20(0x3e720E59E680CBaeEB11AD456faf3FA6F3801EDC);
        // VAULT = IVault(0x47a8aB273dB1b2e45F97d01a09Fcf5cA696Fb997);
        
        DRIP = IBEP20(_dripToken);
        VAULT = IVault(_vault);
    }

    /// @notice Set Staking Contract address Function.
    /// @param _stakingContract Address of the staking contract.
    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0) && _stakingContract != stakingContract, "Not Zero Address");
        stakingContract = _stakingContract;
    }


    /// @notice Set Cool Down Time Function.
    /// @param _newDuration New Cooldown duartion.
    function setCooldownTime(uint256 _newDuration) external onlyOwner {
        require(_newDuration != 0, "Not zero second duration");
        COOL_DOWN = _newDuration;
    }
    
    /// @notice Set PayoutRate Function.
    /// @param _newRate New Payout Rate.
    function setPayoutRate(uint256 _newRate) external onlyOwner {
        require(_newRate != 0, "Not zero can be payout rate");
        PAYOUT_RATE = _newRate;
    }

    /// @notice Claim Reward Function.
    function claim() external {
        
        // Check if now is after COOL_DOWN time
        if (lastTaxTransferTime + COOL_DOWN < block.timestamp) {

            // Get amount of Tax Vault contraact and withdraw all
            uint256 taxBalance = DRIP.balanceOf(address(VAULT));
            VAULT.withdraw(taxBalance);

            // Get 10% of the Tax Vault amount
            uint256 pureBalance = taxBalance.div(10);

            // Burn 90% of the Tax Vault 
            DRIP.transfer(DEAD_ADDRESS, taxBalance.sub(pureBalance));

            lastTaxTransferTime = block.timestamp;
        }

        // Get Treasury Balance and transfer 1% to the StakingContract
        uint256 treasuryBalance = DRIP.balanceOf(address(this));
        
        // A portion of the treasury balance is paid out according to the rate
        uint256 share = treasuryBalance.mul(PAYOUT_RATE).div(100).div(24 hours);

        uint256 claimAmount;

        if (lastPayoutTime == 0) {
            // Get claimAmount as payout Percent of TreasuryBalance
            claimAmount = treasuryBalance.mul(PAYOUT_RATE).div(100);
        } else {
            // Get claimAmount from the passed time from lastPayoutTime
            claimAmount = share.mul(block.timestamp - lastPayoutTime);
        }

        if (claimAmount > treasuryBalance) {
            claimAmount = treasuryBalance;
        }

        DRIP.transfer(stakingContract, claimAmount);

        // Get Last Deposit time as blockTimestamp
        lastPayoutTime = block.timestamp;
    }
}

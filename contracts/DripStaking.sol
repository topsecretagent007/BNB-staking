// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "hardhat/console.sol";

import "./interfaces/IBEP20.sol";
import "./interfaces/ITreasury.sol";

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


abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
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


contract DripStaking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    /// @notice Info of each Staking user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` Used to calculate the correct amount of rewards. See explanation below.
    ///
    /// We do some fancy math here. Basically, any point in time, the amount of DRIPs
    /// entitled to a user but is pending to be distributed is:
    ///
    ///   pending reward = (user share * pool.accDripPerShare) - user.rewardDebt
    ///
    ///   Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
    ///   1. The pool's `accDripPerShare` (and `lastRewardBlock`) gets updated.
    ///   2. User receives the pending reward sent to his/her address.
    ///   3. User's `amount` gets updated. Pool's `totalBoostedShare` gets updated.
    ///   4. User's `rewardDebt` gets updated.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 boostMultiplier;
        uint256 lockStartTime;
        uint256 lockEndTime;
    }

    // @notice Accumulated DRIPs per share, times 1e12.
    uint256 public accDripPerShare;
    // @notice Last block number that pool update action is executed.
    uint256 public lastRewardBlock;
    // @notice The total amount of user shares in each pool. After considering the share boosts.
    uint256 public totalBoostedShare;
    // @notice The DRIP amount to be distributed every block.
    uint256 public dripPerBlock;

    // @notice This year's DRIP totalSupply.
    uint256 public totalSupplyYear;
    // @notice Last calculated the totalSupply time.
    uint256 public lastYearTime;
    // @notice Last mint DRIP time.
    uint256 public lastMintTime;
    // @notice max Lock Duration time.
    uint256 public maxLockDuration;

    /// @notice Address of the LP token for each MCV2 pool.
    IBEP20 public lpToken;
    /// @notice Address of DRIP contract.
    IBEP20 public DRIP;
    /// @notice Address of Treasury contract.
    ITreasury public TREASURY;
    

    /// @notice 
    uint256 public constant ACC_DRIP_PRECISION = 1e18;
    /// @notice 
    uint256 public constant BOOST_PRECISION = 1e12;
    /// @notice
    uint256 public constant DURATION_FACTOR = 365 days;

    /// @notice
    uint256 public constant MIN_LOCK_DURATION = 1 weeks;
    uint256 public constant MAX_LOCK_DURATION = 52 weeks;

    /// @notice 
    uint256 public BOOST_WEIGHT = 20e12;

    /// @notice Info of each pool user & stake Id.
    mapping(address => mapping (uint256 => UserInfo)) public userInfo;
    // @notice The Current Staked Id.
    mapping(address => uint256) public currentStakedId;
    /// @notice Match earned Drip to each user.
    mapping(address => uint256) public earnedDrip;
    /// @notice Match staked LP to each user.
    mapping(address => uint256) public stakedAmount;
    
    event UpdatePool(uint256 lastRewardBlock, uint256 lpSupply, uint256 accDripPerShare);
    event Deposit(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 id);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address _drip, address _lpToken) Ownable(_msgSender()) {
        /// Mainnet
        // DRIP    = IBEP20(0x20f663CEa80FaCE82ACDFA3aAE6862d246cE0333);
        // lpToken = IBEP20(0xB17E674a4B28958A0eF77E608B4fE94c23AceE29);
        
        /// Testnet
        // DRIP    = IBEP20(0x3e720E59E680CBaeEB11AD456faf3FA6F3801EDC);
        // lpToken = IBEP20(0x16567F9Cc0cb4858bcC729285fC836006eE9c81b);

        DRIP = IBEP20(_drip);
        lpToken = IBEP20(_lpToken);

        totalSupplyYear = DRIP.totalSupply();
        lastYearTime = block.timestamp;
    }

    /// @notice View function for checking pending DRIP rewards.
    /// @param _user Address of the user.
    /// @param _stakeId New stake id.
    function pendingDrip(address _user, uint256 _stakeId) external view returns (uint256) {
        UserInfo memory user = userInfo[_user][_stakeId];
        uint256 accPerShare = accDripPerShare;
        uint256 lpSupply = totalBoostedShare;

        if (block.number > lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number.sub(lastRewardBlock);
            uint256 dripReward = multiplier.mul(dripPerBlock);
            accPerShare = accPerShare.add(dripReward.mul(ACC_DRIP_PRECISION).div(lpSupply));
        }

        uint256 boostedAmount = user.amount.mul(user.boostMultiplier).div(BOOST_PRECISION);
        return boostedAmount.mul(accPerShare).div(ACC_DRIP_PRECISION).sub(user.rewardDebt);
    }

    /// @notice Update reward variables for the given pool.
    function updatePool() public {
        if (block.number > lastRewardBlock) {
            uint256 lpSupply = totalBoostedShare;

            if (lpSupply > 0 ) {
                uint256 multiplier = block.number.sub(lastRewardBlock).sub(1);
                uint256 dripReward = multiplier.mul(dripPerBlock);

                accDripPerShare = accDripPerShare.add(dripReward.mul(ACC_DRIP_PRECISION).div(lpSupply));
            }
            uint256 mintableAmount = totalSupplyYear.mul(5).div(100).mul(block.timestamp - lastMintTime).div(365 days);
            DRIP.mint(address(this), mintableAmount);

            if (block.timestamp > lastYearTime + 365 days) {
                lastYearTime = lastYearTime + 365 days;
                totalSupplyYear = DRIP.totalSupply();
            }

            lastRewardBlock = block.number;
            lastMintTime = block.timestamp;

            emit UpdatePool(lastRewardBlock, lpSupply, accDripPerShare);
        }
    }


    /// @notice stake LP tokens to pool.
    /// @param _amount LP token's lock amount.
    /// @param _lockDuration LP token's lock duration.
    function stake(uint256 _amount, uint256 _lockDuration) external nonReentrant {
        updatePool();
        address sender = msg.sender;
        UserInfo storage user = userInfo[sender][currentStakedId[sender]];

        require(_lockDuration >= MIN_LOCK_DURATION, "Minimum lock period is one week");
        require(_lockDuration <= MAX_LOCK_DURATION, "Maximum lock period exceeded");

        // Update lock duration.
        if (_lockDuration > 0) {
            user.lockStartTime = block.timestamp;
            user.lockEndTime = block.timestamp + _lockDuration;
        }

        uint256 multiplier = getBoostMultiplier(_lockDuration);

        if (_amount > 0) {
            uint256 before = lpToken.balanceOf(address(this));
            lpToken.transferFrom(sender, address(this), _amount);
            _amount = lpToken.balanceOf(address(this)).sub(before);
            user.amount = user.amount.add(_amount);
            user.boostMultiplier = multiplier;

            // Update total boosted share.
            totalBoostedShare = totalBoostedShare.add(_amount.mul(multiplier).div(BOOST_PRECISION));
        }

        user.rewardDebt = user.amount.mul(multiplier).div(BOOST_PRECISION).mul(accDripPerShare).div(
            ACC_DRIP_PRECISION
        );

        stakedAmount[sender] += _amount;
        currentStakedId[sender] += 1;

        if(maxLockDuration < _lockDuration) {
            maxLockDuration = _lockDuration;
        }

        emit Deposit(sender, _amount);
    }

    /// @notice claim Rewaqrd from pool.
    /// @param _stakedId Id of Pool.
    function claim(uint256 _stakedId) external nonReentrant {
        updatePool();
        address sender = msg.sender;
        UserInfo storage user = userInfo[sender][_stakedId];
        uint256 multiplier = user.boostMultiplier;

        settlePendingDrip(sender, _stakedId);

        user.rewardDebt = user.amount.mul(multiplier).div(BOOST_PRECISION).mul(accDripPerShare).div(
            ACC_DRIP_PRECISION
        );

        emit Claim(sender, _stakedId);
    }

    /// @notice Withdraw LP tokens from pool.
    /// @param _stakedId Staked Id to withdraw.
    function withdraw(uint256 _stakedId) external nonReentrant {
        updatePool();
        address sender = msg.sender;
        UserInfo storage user = userInfo[sender][_stakedId];

        require(user.lockEndTime <= block.timestamp, "withdraw: locked");

        lpToken.transfer(sender, user.amount);

        uint256 multiplier = user.boostMultiplier;

        settlePendingDrip(sender, _stakedId);
        
        totalBoostedShare = totalBoostedShare.sub(
            user.amount.mul(multiplier).div(BOOST_PRECISION)
        );
        currentStakedId[sender]--;
        stakedAmount[sender] -= user.amount;

        UserInfo storage lastUser = userInfo[sender][currentStakedId[sender]];
       
        user.amount = lastUser.amount;
        user.rewardDebt = lastUser.rewardDebt;
        user.boostMultiplier = lastUser.boostMultiplier;
        user.lockStartTime = lastUser.lockStartTime;
        user.lockEndTime = lastUser.lockEndTime;

        delete userInfo[sender][currentStakedId[sender]];

        emit Withdraw(sender, _stakedId);
    }
  
    /// @notice Settles, distribute the pending DRIP rewards for given user.
    /// @param _user The user address for settling rewards.
    /// @param _stakedId The stakedId for settling rewards.
    function settlePendingDrip(
        address _user,
        uint256 _stakedId
    ) internal {
        UserInfo storage user = userInfo[_user][_stakedId];

        uint256 boostedAmount = user.amount.mul(user.boostMultiplier).div(BOOST_PRECISION);
        uint256 pending = boostedAmount.mul(accDripPerShare).div(ACC_DRIP_PRECISION).sub(user.rewardDebt);
        
        // SafeTransfer DRIP
        _safeTransfer(_user, pending);

        // Add pending Drip amount to the earnedDrip
        earnedDrip[_user] += pending;
        
    }

    
    /// @notice Safe Transfer DRIP.
    /// @param _to The DRIP receiver address.
    /// @param _amount transfer DRIP amounts.
    function _safeTransfer(address _to, uint256 _amount) internal {
        if (_amount > 0) {
            TREASURY.claim();
            // Transfer DRIP token to users
            DRIP.transfer(_to, _amount);
        }
    }

    /// @notice Update TREASURY contract.
    /// @param _newTreasury Treasury Contract address.
    function updateTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0) && _newTreasury != address(TREASURY), "Not Zero Address");
        TREASURY = ITreasury(_newTreasury);
    }

    /// @notice Update dripPerBlock.
    /// @param _newDrip new DripPerBlock amount.
    function updateDripPerBlock(uint256 _newDrip) external onlyOwner {
        require(_newDrip != 0 && _newDrip != dripPerBlock, "Not Zero Amount");
        dripPerBlock = _newDrip;
    }

    /// @notice Get the boost calculation.
    /// @param _duration user's lock duration.
    function getBoostMultiplier(
        uint256 _duration
    ) public view returns (uint256) {

        if (_duration == 0) return BOOST_PRECISION;

        uint256 multiplier =  _duration.mul(BOOST_WEIGHT).div(DURATION_FACTOR);

        // should "*" BOOST_PRECISION
        return multiplier + BOOST_PRECISION;
    }

    /// @notice Set BOOST_WEIGHT
    /// @param _boostWeight new BoostWeight amount.
     function setBoostWeight(uint256 _boostWeight) external onlyOwner {
        require(_boostWeight <= BOOST_PRECISION, "BOOST_WEIGHT cannot be more than BOOST_WEIGHT_LIMIT");
        BOOST_WEIGHT = _boostWeight;
    }

}
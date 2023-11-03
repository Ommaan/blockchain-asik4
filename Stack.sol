// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract StakeHolder is Ownable, ReentrancyGuard {
    uint256 public stakingPeriod; // Staking period in seconds
    uint256 public minStakeAmount; // Minimum staking amount
    uint256 public totalStaked; // Total staked amount
    uint256 public totalRewardsDistributed; // Total rewards distributed
    uint256 public rewardsPerPeriod; // Rewards per staking period
    address[] public stakers;

    enum StakingStatus { PENDING, ACTIVE, ENDED }
    StakingStatus public stakingStatus;

    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public rewardsEarned;
    mapping(address => uint256) public stakingStartTimes;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 stakedAmount, uint256 rewards);

    constructor(uint256 _stakingPeriod, uint256 _minStakeAmount, uint256 _rewardsPerPeriod) {
        stakingPeriod = _stakingPeriod;
        minStakeAmount = _minStakeAmount;
        rewardsPerPeriod = _rewardsPerPeriod;
        stakingStatus = StakingStatus.PENDING;
    }

    modifier whenStakingActive() {
        require(stakingStatus == StakingStatus.ACTIVE, "Staking is not active");
        _;
    }

    modifier whenStakingEnded() {
        require(stakingStatus == StakingStatus.ENDED, "Staking is still active");
        _;
    }

    function startStaking() external onlyOwner {
        require(stakingStatus == StakingStatus.PENDING, "Staking has already started");
        stakingStatus = StakingStatus.ACTIVE;
    }

    function endStaking() external onlyOwner {
        require(stakingStatus == StakingStatus.ACTIVE, "Staking is not active");
        stakingStatus = StakingStatus.ENDED;
    }

    function stakeTokens() external payable whenStakingActive {
        require(msg.value >= minStakeAmount, "Insufficient staking amount");
        stakedBalances[msg.sender] += msg.value;
        stakingStartTimes[msg.sender] = block.timestamp;
        totalStaked += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    function calculateRewards(address staker) internal view returns (uint256) {
        uint256 stakingDuration = block.timestamp - stakingStartTimes[staker];
        return (stakedBalances[staker] * stakingDuration * rewardsPerPeriod) / stakingPeriod;
    }

    function distributeRewards() external whenStakingEnded {
        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 rewards = calculateRewards(staker);
            rewardsEarned[staker] += rewards;
            totalRewardsDistributed += rewards;
        }
    }

    function withdraw() external whenStakingEnded {
        uint256 stakedAmount = stakedBalances[msg.sender];
        require(stakedAmount > 0, "No staked amount to withdraw");

        uint256 rewards = rewardsEarned[msg.sender];
        stakedBalances[msg.sender] = 0;
        rewardsEarned[msg.sender] = 0;
        totalStaked -= stakedAmount;
        totalRewardsDistributed -= rewards;

        payable(msg.sender).transfer(stakedAmount + rewards);
        emit Withdrawn(msg.sender, stakedAmount, rewards);
    }

    function checkStakedBalance(address staker) external view returns (uint256) {
        return stakedBalances[staker];
    }

    function checkEarnedRewards(address staker) external view returns (uint256) {
        return rewardsEarned[staker];
    }
}

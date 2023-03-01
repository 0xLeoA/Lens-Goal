// SPDX-License-Identifier: MIT

// $$\                                           $$$$$$\                      $$\
// $$ |                                         $$  __$$\                     $$ |
// $$ |      $$$$$$\  $$$$$$$\   $$$$$$$\       $$ /  \__| $$$$$$\   $$$$$$\  $$ |
// $$ |     $$  __$$\ $$  __$$\ $$  _____|      $$ |$$$$\ $$  __$$\  \____$$\ $$ |
// $$ |     $$$$$$$$ |$$ |  $$ |\$$$$$$\        $$ |\_$$ |$$ /  $$ | $$$$$$$ |$$ |
// $$ |     $$   ____|$$ |  $$ | \____$$\       $$ |  $$ |$$ |  $$ |$$  __$$ |$$ |
// $$$$$$$$\\$$$$$$$\ $$ |  $$ |$$$$$$$  |      \$$$$$$  |\$$$$$$  |\$$$$$$$ |$$ |
// \________|\_______|\__|  \__|\_______/        \______/  \______/  \_______|\__|

// Team Lens Handles:
// cryptocomical.lens       | Designer
// (Add Greg's name here)   | Front-End and Smart Contract developer
// leoawolanski.lens        | Smart Contract Developer

pragma solidity 0.8.17;

import "./LensGoalHelpers.sol";
import "./AutomationCompatible.sol";
import "./AutomationCompatibleInterface.sol";

contract LensGoal is LensGoalHelpers {
    // wallet where funds will be transfered in case of goal failure
    // is currently the 0 address for simplicity, edit later

    address communityWallet = address(0);
    uint256 constant HOURS_24 = 1 days;
    uint256 constant MINUTES_6 = 60 * 6;

    // used to identify whether stake is in ether or erc20
    enum TokenType {
        ETHER,
        ERC20
    }

    // GoalStatus enum, used to check goal status (e.g. "pending", "true", "false")
    enum GoalStatus {
        PENDING,
        VOTED_TRUE,
        VOTED_FALSE
    }

    struct Votes {
        uint256 yes;
        uint256 no;
    }

    struct Stake {
        // stake can be ether or erc20
        TokenType tokenType;
        uint256 amount;
        // is address(0) if token type is ether
        address tokenAddress;
    }

    struct Goal {
        string description;
        string verificationCriteria;
        Stake stake;
        Votes votes;
        GoalStatus status;
        uint256 goalId;
        AdditionalStake[] additionalstakes;
        address user;
    }

    struct AdditionalStake {
        Stake stake;
        uint256 stakeId;
        uint256 goalId;
        address staker;
    }

    mapping(address => uint256[]) public userToGoalIds;
    mapping(address => uint256[]) public userToStakeIds;
    mapping(uint256 => Goal) public goalIdToGoal;
    mapping(uint256 => AdditionalStake) public stakeIdToStake;

    uint256 goalId;
    uint256 stakeId;

    function makeNewGoal(
        string memory description,
        string memory verificationCriteria,
        bool inEther,
        uint256 tokenAmount,
        address tokenAddress
    ) external payable {
        if (inEther) {
            require(msg.value > 0, "msg.value must be greater than 0");
            AdditionalStake[] memory additionalstakes;
            Goal memory goal = Goal(
                description,
                verificationCriteria,
                defaultEtherStake(),
                Votes(0, 0),
                GoalStatus.PENDING,
                goalId,
                // empty list as input
                additionalstakes,
                msg.sender
            );
            userToGoalIds[msg.sender].push(goalId);
            goalIdToGoal[goalId] = goal;
            // increment goalId for later goal instantiation
            goalId++;
        } else {
            // safety check
            require(tokenAmount > 0, "tokenAmount must be greater than 0");
            // transfer tokens to contracts
            require(
                IERC20(tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    tokenAmount
                ) == true,
                "token transfer failed. check your approvals"
            );
            AdditionalStake[] memory additionalstakes;
            Goal memory goal = Goal(
                description,
                verificationCriteria,
                Stake(TokenType.ERC20, tokenAmount, tokenAddress),
                Votes(0, 0),
                GoalStatus.PENDING,
                goalId,
                additionalstakes,
                msg.sender
            );
            userToGoalIds[msg.sender].push(goalId);
            goalIdToGoal[goalId] = goal;
            goalId++;
        }
    }

    function makeNewStake(
        /* which goal the stake is for**/ uint256 _goalId,
        bool inEther,
        uint256 tokenAmount,
        address tokenAddress
    ) external payable {
        if (inEther) {
            require(msg.value > 0, "msg.value must be greater than 0");
            AdditionalStake memory stake = AdditionalStake(
                defaultEtherStake(),
                stakeId,
                _goalId,
                msg.sender
            );
            userToStakeIds[msg.sender].push(stakeId);
            goalIdToGoal[_goalId].additionalstakes.push(stake);
            stakeIdToStake[stakeId] = stake;
            stakeId++;
        } else {
            require(tokenAmount > 0, "tokenAmount must be greater than 0");
            AdditionalStake memory stake = AdditionalStake(
                Stake(TokenType.ERC20, tokenAmount, tokenAddress),
                stakeId,
                _goalId,
                msg.sender
            );
            userToStakeIds[msg.sender].push(stakeId);
            goalIdToGoal[_goalId].additionalstakes.push(stake);
            stakeIdToStake[stakeId] = stake;
            stakeId++;
        }
    }

    function defaultEtherStake() internal view returns (Stake memory) {
        return Stake(TokenType.ETHER, msg.value, address(0));
    }
}

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

    // TokenType enum, used in newGoal and additionalStake struct to identify whether stake is in ether or erc20
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

    struct newGoal {
        string description;
        address user;
        TokenType tokenType;
        uint256 tokenAmount;
        // address(0) if token type is ether
        address tokenAddress;
        // in unix timestamp format
        uint256 endTime;
        // newGoal's place in goals array
        uint256 goalId;
        GoalStatus status;
        additionalStake[] stakes;
    }

    // friends can stake additional tokens/ether and are able to withdraw them at any time
    // (unless the goal they are staking for is voted true and tokens are sent off)
    // the allowed withdrawals are implemented to remove unfair voting
    // if user fails goal, all additional stakes will be sent back to their stakers
    struct additionalStake {
        address staker;
        // determines if stake is in ether or erc20
        TokenType tokenType;
        uint256 tokenAmount;
        // defaults to address(0) if token type is ether
        address tokenAddress;
        // if donator decides to withdraw stake or voting windows is closed and funds are sent off, stakeWithdrawn will = true
        // defaults to false
        bool stakeWithdrawn;
        // global stakeId (stake's index in additionalStakes array)
        uint256 stakeId;
        // local stakeId (stake's index in (address => stakeList))
        uint256 localStakeId;
        // stake's index in goal stake array
        uint256 indexInGoalArray;
        // common global index
        // shared with the goal this stake is for
        // (e.g if goal has index 0 in goals list, goalId here is also 0)
        // this is how the amount of stakes for a specific goal is identified
        uint256 goalId;
    }

    // goal array (all goals are stored here)
    newGoal[] public goals;
    // address to list of goals mapping
    mapping(address => newGoal[]) public userToGoals;
    // address to all created additionalStakes mapping
    // (all additionalStakes that specific address created)
    mapping(address => additionalStake[]) public addressToAdditionalStakes;
    // array of additionalStakes
    additionalStake[] public additionalStakes;

    function makeGoal(
        string memory description,
        bool inEther,
        uint256 tokenAmount,
        address tokenAddress,
        uint256 endTime
    ) external payable {
        // tokenAmount and tokenAddress default to 0 and address(0) if inEth == True
        // 60*60*24 seconds = 1 day
        // On web page user will be prompted to select options ranging from at least a day
        // allows for up to a 6 minute time delay between function call initiation in metamask and user submission / tx confirmation
        require(
            endTime > (block.timestamp + 60 * 60 * 24 - 360),
            "goal must end at least a day after initiation"
        );
        additionalStake[] memory additionalstakes;
        if (inEther == true) {
            // add new goal to goals list
            newGoal memory goal = newGoal(
                description,
                msg.sender,
                TokenType.ETHER,
                msg.value,
                address(0),
                endTime,
                goals.length,
                GoalStatus.PENDING,
                additionalstakes
            );
            goals.push(goal);
            // append new goal to (address => goals) mapping
            userToGoals[msg.sender].push(goal);
        }
        if (inEther == false) {
            // transfer ERC20 tokens to contract
            require(
                IERC20(tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    tokenAmount
                ) == true,
                "transfer from tx failed, check approval settings"
            );
            newGoal memory goal = newGoal(
                description,
                msg.sender,
                TokenType.ERC20,
                tokenAmount,
                tokenAddress,
                endTime,
                goals.length,
                GoalStatus.PENDING,
                additionalstakes
            );
            goals.push(goal);
            userToGoals[msg.sender].push(goal);
        }
    }

    function makeAdditionalStake(
        bool inEther,
        uint256 tokenAmount,
        address tokenAddress,
        // identifies which goal the stake is for
        uint256 goalId
    ) external payable {
        require(goalId <= goals.length - 1, "non existing index");
        // if token type is ether, tokenAddress will be "ignored" and set to address(0)
        if (inEther == true) {
            require(msg.value > 0, "cannot stake 0 matic");
            additionalStake memory newStake = additionalStake(
                msg.sender,
                TokenType.ETHER,
                msg.value,
                address(0),
                false,
                additionalStakes.length,
                addressToAdditionalStakes[msg.sender].length,
                goals[goalId].stakes.length,
                goalId
            );
            goals[goalId].stakes.push(newStake);
            addressToAdditionalStakes[msg.sender].push(newStake);
            additionalStakes.push(newStake);
        }
        if (inEther == false) {
            require(tokenAmount > 0, "cannot stake 0 tokens");
            require(
                IERC20(tokenAddress).transferFrom(
                    msg.sender,
                    address(this),
                    tokenAmount
                ) == true,
                "token transfer failed, check approval settings"
            );
            additionalStake memory newStake = additionalStake(
                msg.sender,
                TokenType.ERC20,
                tokenAmount,
                tokenAddress,
                false,
                additionalStakes.length,
                addressToAdditionalStakes[msg.sender].length,
                goals[goalId].stakes.length,
                goalId
            );
            goals[goalId].stakes.push(newStake);
            addressToAdditionalStakes[msg.sender].push(newStake);
            additionalStakes.push(newStake);
        }
    }

    function withdrawStake(uint256 stakeId) external {
        additionalStake memory stake = additionalStakes[stakeId];
        // authenticate msg.sender
        require(msg.sender == stake.staker, "not staker");
        // check to make sure stake is not already withdrawn to prevent theft
        require(stake.stakeWithdrawn == false, "stake already withdrawn");
        if (stake.tokenType == TokenType.ETHER) {
            payable(msg.sender).transfer(stake.tokenAmount);
            updateStakes(stakeId);
        } else {
            IERC20(stake.tokenAddress).transfer(
                stake.staker,
                stake.tokenAmount
            );
            updateStakes(stakeId);
        }
    }

    // changes all stake objects in storage with the same stakeId to withdrawn
    // used in withdrawStake()
    function updateStakes(uint256 stakeId) internal {
        additionalStake memory stake = additionalStakes[stakeId];
        uint256 goalId = stake.goalId;
        address staker = stake.staker;
        uint256 localStakeId = stake.localStakeId;
        uint256 indexInGoalArray = stake.indexInGoalArray;

        additionalStakes[stakeId].stakeWithdrawn == true;
        addressToAdditionalStakes[staker][localStakeId].stakeWithdrawn == true;
        goals[goalId].stakes[indexInGoalArray].stakeWithdrawn == true;
    }
}


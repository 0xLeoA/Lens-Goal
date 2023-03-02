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

contract LensGoal is LensGoalHelpers, AutomationCompatibleInterface {
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
    enum Status {
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

    struct GoalBasicInfo {
        address user;
        string description;
        string verificationCriteria;
        uint256 deadline;
        Status status;
        uint256 goalId;
    }

    struct Goal {
        GoalBasicInfo info;
        Stake stake;
        Votes votes;
        AdditionalStake[] additionalstakes;
        string[] proofs;
    }

    struct AdditionalStake {
        Stake stake;
        uint256 stakeId;
        // which goal this stake belongs to
        uint256 goalId;
        address staker;
        // used for withdrawStake()
        // if withdraw == true, stake cannot be withdrawn
        bool withdrawn;
    }

    // get address's stake and goal ids
    mapping(address => uint256[]) public userToGoalIds;
    mapping(address => uint256[]) public userToStakeIds;
    // each id is a goal or stake
    mapping(uint256 => Goal) public goalIdToGoal;
    mapping(uint256 => AdditionalStake) public stakeIdToStake;

    // will be incremented when new goals/stakes are published
    uint256 goalId;
    uint256 stakeId;

    // allows user to make a new goal
    function makeNewGoal(
        string memory description,
        string memory verificationCriteria,
        bool inEther,
        uint256 tokenAmount,
        address tokenAddress,
        uint256 timestampEnd
    ) external payable {
        if (inEther) {
            // require(msg.value > 0, "msg.value must be greater than 0");
            // why user can stake nothing:
            // so that user can have friends stake as "rewards" and themselves stake nothing
            AdditionalStake[] memory additionalstakes;
            string[] memory proofs;
            Goal memory goal = Goal(
                GoalBasicInfo(
                    msg.sender,
                    description,
                    verificationCriteria,
                    timestampEnd,
                    Status.PENDING,
                    goalId
                ),
                defaultEtherStake(),
                Votes(0, 0),
                additionalstakes,
                proofs
            );
            userToGoalIds[msg.sender].push(goalId);
            goalIdToGoal[goalId] = goal;
            // increment goalId for later goal instantiation
            goalId++;
        } else {
            // require(tokenAmount > 0, "tokenAmount must be greater than 0");
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
            string[] memory proofs;
            Goal memory goal = Goal(
                // define info struct
                GoalBasicInfo(
                    msg.sender,
                    description,
                    verificationCriteria,
                    timestampEnd,
                    Status.PENDING,
                    goalId
                ),
                // get etherstake struct
                defaultEtherStake(),
                // votes struct
                Votes(0, 0),
                // empty list s
                additionalstakes,
                proofs
            );
            // push goalId
            userToGoalIds[msg.sender].push(goalId);
            // define goalId
            goalIdToGoal[goalId] = goal;
            // increment goalId (for future use)
            goalId++;
        }
    }

    // quickly get a Stake struct where token is ether
    function defaultEtherStake() internal view returns (Stake memory) {
        return Stake(TokenType.ETHER, msg.value, address(0));
    }

    // allows users to make additional stakes
    function makeNewStake(
        /* which goal the stake is for**/ uint256 _goalId,
        bool inEther,
        uint256 tokenAmount,
        address tokenAddress
    ) external payable {
        if (inEther) {
            // cannot stake 0 tokens
            require(msg.value > 0, "msg.value must be greater than 0");
            AdditionalStake memory stake = AdditionalStake(
                defaultEtherStake(),
                stakeId,
                _goalId,
                msg.sender,
                false
            );
            // push stakeId
            userToStakeIds[msg.sender].push(stakeId);
            // add stake to goal
            goalIdToGoal[_goalId].additionalstakes.push(stake);
            // define stake in mapping
            stakeIdToStake[stakeId] = stake;
            // increment stakeId for future use
            stakeId++;
        } else {
            // cannot stake 0 tokens
            require(tokenAmount > 0, "tokenAmount must be greater than 0");
            AdditionalStake memory stake = AdditionalStake(
                Stake(TokenType.ERC20, tokenAmount, tokenAddress),
                stakeId,
                _goalId,
                msg.sender,
                false
            );
            // push stakeId
            userToStakeIds[msg.sender].push(stakeId);
            // add stake to goal
            goalIdToGoal[_goalId].additionalstakes.push(stake);
            // define stake in mapping
            stakeIdToStake[stakeId] = stake;
            // increment stakeId for future use
            stakeId++;
        }
    }

    // users can write or link to proof on chain to convince voters to vote positevely
    function writeProofs(
        /** input of strings to write */ string[] memory _proofs,
        uint256 _goalId
    ) external {
        // check for user to be goal initiator
        require(
            goalIdToGoal[_goalId].info.user == msg.sender,
            "not goal creator"
        );
        // iterate through each proof and append to proofs list
        for (uint256 i; i < goalId; i++) {
            goalIdToGoal[_goalId].proofs.push(_proofs[i]);
        }
    }

    // get info of goal (for front end)
    function getBasicInfo(
        uint256 _goalId
    ) public view returns (GoalBasicInfo memory) {
        return goalIdToGoal[_goalId].info;
    }

    // vote on goal
    function vote(
        uint256 _goalId,
        bool input
    )
        external
        /** make sure voting windows is open */ windowOpen(
            goalIdToGoal[_goalId].info.deadline
        )
    {
        if (input == true) {
            goalIdToGoal[_goalId].votes.yes++;
        } else {
            goalIdToGoal[_goalId].votes.no++;
        }
    }

    // checks if voting window is open
    modifier windowOpen(uint256 startTimestamp) {
        require(
            block.timestamp > startTimestamp &&
                block.timestamp < startTimestamp + 1 days
        );
        _;
    }

    // allows stakers to withdraw stake so that they don't purposely vote negatively to get it back
    function withdrawStake(uint256 _stakeId) external {
        // identity check
        require(stakeIdToStake[_stakeId].staker == msg.sender, "not staker");
        // safety check
        require(
            stakeIdToStake[_stakeId].withdrawn == false,
            "stake already withdrawn"
        );
        // if stake is in ether, send ether back to msg.sender and set withdrawn to true
        if (stakeIdToStake[_stakeId].stake.tokenType == TokenType.ETHER) {
            payable(msg.sender).transfer(stakeIdToStake[_stakeId].stake.amount);
            stakeIdToStake[_stakeId].withdrawn = true;
        } else {
            IERC20(stakeIdToStake[_stakeId].stake.tokenAddress).transfer(
                msg.sender,
                stakeIdToStake[_stakeId].stake.amount
            );
            stakeIdToStake[_stakeId].withdrawn = true;
        }
    }

    // Chainlink view function. If returns true, Chainlink will run state-changing performUpkeep() function
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        for (uint256 i; i < goalId; i++) {
            if (
                block.timestamp > goalIdToGoal[i].info.deadline + 1 days &&
                goalIdToGoal[i].info.status == Status.PENDING
            ) {
                return (true, bytes("LensGoal"));
            }
        }
        return (false, bytes("LensGoal"));
    }

    // Chainlink state changing transaction. Will run if checkUpkeep() returns true
    function performUpkeep(bytes calldata /* performData */) external override {
        // loop through all goals
        for (uint256 i; i < goalId; i++) {
            // define goal var
            // check if voting window has closed and Status has not been set to pending
            // if status has not been set to pending, that means that the voting window has just closed
            if (
                block.timestamp > goalIdToGoal[i].info.deadline + 1 days &&
                goalIdToGoal[i].info.status == Status.PENDING
            ) {
                // get result of votes
                bool accomplishedGoal = evaluateVotes(i);
                // if voted true, transfer stakes to user and update status
                if (accomplishedGoal) {
                    transferStakes(
                        accomplishedGoal,
                        goalIdToGoal[i].info.goalId
                    );
                    goalIdToGoal[i].info.status = Status.VOTED_TRUE;
                } else {
                    transferStakes(
                        accomplishedGoal,
                        goalIdToGoal[i].info.goalId
                    );
                    goalIdToGoal[i].info.status = Status.VOTED_FALSE;
                }
            }
        }
    }

    // function evaluates votes
    function evaluateVotes(uint256 _goalId) internal view returns (bool) {
        Votes memory _votes = goalIdToGoal[_goalId].votes;
        // if 0 votes, send funds back to user
        if (_goalId == 0) {
            return true;
        }
        // if more yes than no, answer is true
        if (_votes.yes > _votes.no) {
            return true;
        }
        // if more no than yes, answer is false
        else if (_votes.no > _votes.yes) {
            return false;
        }
        // if there is an equal amount of yes and no votes, answer is true
        else {
            return true;
        }
    }

    // function transfers additional stakes (if any) and user stake to user/community wallet
    function transferStakes(
        /* stakes will be transfered to user or to community wallet/back to stakers depending on this bool */ bool userAccomplishedGoal,
        uint256 _goalId
    ) internal {
        transferUserStake(userAccomplishedGoal, _goalId);
        if (goalIdToGoal[_goalId].additionalstakes.length > 0) {
            if (userAccomplishedGoal) {
                for (
                    uint256 i;
                    i < goalIdToGoal[_goalId].additionalstakes.length;
                    i++
                ) {
                    transferStakeToUser(
                        goalIdToGoal[_goalId].additionalstakes[i].stakeId
                    );
                }
            } else {
                for (
                    uint256 i;
                    i < goalIdToGoal[_goalId].additionalstakes.length;
                    i++
                ) {
                    transferStakeBackToStaker(
                        goalIdToGoal[_goalId].additionalstakes[i].stakeId
                    );
                }
            }
        }
    }

    // function transfers stake back to its staker
    function transferStakeBackToStaker(uint256 _stakeId) internal {
        // safety check
        if (stakeIdToStake[_stakeId].withdrawn == false) {
            if (stakeIdToStake[_stakeId].stake.tokenType == TokenType.ETHER) {
                // if stake is in ether, transfer stake amount back to staker
                payable(stakeIdToStake[_stakeId].staker).transfer(
                    stakeIdToStake[_stakeId].stake.amount
                );
            } else {
                // if stake is in erc20, transfer tokens back to staker
                IERC20(stakeIdToStake[_stakeId].stake.tokenAddress).transfer(
                    stakeIdToStake[_stakeId].staker,
                    stakeIdToStake[_stakeId].stake.amount
                );
            }
            // make sure to set withdrawn to true
            stakeIdToStake[_stakeId].withdrawn = true;
        }
    }

    // function transfers stake to user
    function transferStakeToUser(uint256 _stakeId) internal {
        address user = goalIdToGoal[stakeIdToStake[_stakeId].goalId].info.user;
        // safety check
        if (stakeIdToStake[_stakeId].withdrawn == false) {
            if (stakeIdToStake[_stakeId].stake.tokenType == TokenType.ETHER) {
                // if stake is in ether, transfer stake amount to user
                payable(user).transfer(stakeIdToStake[_stakeId].stake.amount);
            } else {
                // transfer tokens to user
                IERC20(stakeIdToStake[_stakeId].stake.tokenAddress).transfer(
                    user,
                    stakeIdToStake[_stakeId].stake.amount
                );
            }
            // make sure to set withdrawn to true
            stakeIdToStake[_stakeId].withdrawn = true;
        }
    }

    // function transfers user stake to user/community wallet
    function transferUserStake(
        bool accomplishedGoal,
        uint256 _goalId
    ) internal {
        // safety check
        require(
            goalIdToGoal[_goalId].info.status == Status.PENDING,
            "goal complete"
        );

        if (accomplishedGoal) {
            // if stake is in ether, transfer ether back to user
            if (goalIdToGoal[_goalId].stake.tokenType == TokenType.ETHER) {
                payable(goalIdToGoal[_goalId].info.user).transfer(
                    goalIdToGoal[_goalId].stake.amount
                );
            }
            // if stake is in erc20, transfer tokens to user
            else {
                IERC20(goalIdToGoal[_goalId].stake.tokenAddress).transfer(
                    goalIdToGoal[_goalId].info.user,
                    goalIdToGoal[_goalId].stake.amount
                );
            }
        } else {
            // if stake is in ether, transfer ether to community wallet
            if (goalIdToGoal[_goalId].stake.tokenType == TokenType.ETHER) {
                payable(communityWallet).transfer(
                    goalIdToGoal[_goalId].stake.amount
                );
            }
            // if stake is in erc20, transfer tokens to community wallet
            else {
                IERC20(goalIdToGoal[_goalId].stake.tokenAddress).transfer(
                    communityWallet,
                    goalIdToGoal[_goalId].stake.amount
                );
            }
        }
    }
}

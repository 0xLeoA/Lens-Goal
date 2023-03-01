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
// (Add Greg's name here)   | Front-End / Smart Contract developer
// leoawolanski.lens        | Smart Contract Developer

pragma solidity 0.8.17;

import "./LensGoalHelpers.sol";
import "./AutomationCompatible.sol";
import "./AutomationCompatibleInterface.sol";

contract LensGoal is LensGoalHelpers, AutomationCompatibleInterface {

    // wallet funds will be transfered here in case of goal failure
    // is currently the 0 address for simplicity, edit later
    address communityWallet = address(0);
    
    // Goal Mappings
    mapping(address => GoalEtherStake[]) public addressToGoalEtherStakes;
    mapping(address => GoalTokenStake[]) public addressToGoalTokenStakes;

    // READER'S NOTE: LIST INDEX IS INDEX OF GOAL IN GLOBAL ARRAY
    // EACH GOAL OBJECT HAS ITS OWN UNIQUE LIST INDEX
    // List Index to Votes mappings
    // when voting time comes, votes will be sorted through list indexes
    mapping(uint256 => bool[]) public listIndexToVotesEtherStake;
    mapping(uint256 => bool[]) public listIndexToVotesTokenStake;
    
    // Global Goal Arrays
    // User may choose to stake either ERC20 tokens or Ether 
    GoalEtherStake[] public GoalEtherStakes;
    GoalTokenStake[] public GoalTokenStakes;

    // Goal created with an Ether stake
    struct GoalEtherStake {
        address user;
        string goal;
        uint256 timestampEnd;
        uint256 etherAmount;
        uint256 listIndex;
        State state;
    }
    // Goal created with an ERC20 token stae
    struct GoalTokenStake {
        address user;
        string goal;
        uint256 timestampEnd;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 listIndex;
        State state;
    }

    enum State {
        IN_PROCCESS,
        VOTED_FALSE,
        VOTED_TRUE
    }

    event GoalEtherStakeCreated(
        address indexed _user,
        string _goal,
        uint256 _timestampEnd,
        uint256 _etherAmount,
        uint256 _listIndex
    );
    event GoalTokenStakeCreated(
        address indexed _user,
        string _goal,
        uint256 _timestampEnd,
        address indexed _tokenAddress,
        uint256 _tokenAmount,
        uint256 _listIndex
    );

    event GoalEtherStakeVote(
        address indexed _voter,
        bool _vote,
        uint256 _listIndex
    );
    event GoalTokenStakeVote(
        address indexed _voter,
        bool _vote,
        uint256 _listIndex
    );


    function makeGoalEtherStake(
        string memory goalDescription,
        uint256 timestampEnd
    ) external payable {
        // 86400 seconds = 24 hours
        // 400 second delay to account for slow users
        require(
            timestampEnd > (block.timestamp + 86000),
            "goal must end in at least a day after initialization, try again"
        );
        // map user to goal
        addressToGoalEtherStakes[msg.sender].push(
            GoalEtherStake(
                msg.sender,
                goalDescription,
                timestampEnd,
                msg.value,
                GoalEtherStakes.length,
                State.IN_PROCCESS
            )
        );
        // add goal to list
        GoalEtherStakes.push(
            addressToGoalEtherStakes[msg.sender][
                addressToGoalEtherStakes[msg.sender].length - 1
            ]
        );
        emit GoalEtherStakeCreated(
            msg.sender,
            goalDescription,
            timestampEnd,
            msg.value,
            GoalEtherStakes.length - 1
        );
    }

    function makeGoalTokenStake(
        string memory goalDescription,
        uint256 timestampEnd,
        address tokenAddress,
        uint256 tokenAmount
    ) external {
        require(
            timestampEnd > (block.timestamp + 86000),
            "goal must end in at least a day after initialization"
        );
        require(
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                tokenAmount
            ) == true,
            "token transfer failed, check your approval settings"
        );

        // map user to goal
        addressToGoalTokenStakes[msg.sender].push(
            GoalTokenStake(
                msg.sender,
                goalDescription,
                timestampEnd,
                tokenAddress,
                tokenAmount,
                GoalTokenStakes.length,
                State.IN_PROCCESS
            )
        );
        // add goal to list
        GoalTokenStakes.push(
            addressToGoalTokenStakes[msg.sender][
                addressToGoalTokenStakes[msg.sender].length - 1
            ]
        );
        emit GoalTokenStakeCreated(
            msg.sender,
            goalDescription,
            timestampEnd,
            tokenAddress,
            tokenAmount,
            GoalTokenStakes.length - 1
        );
    }

    function voteOnTokenStake(uint256 goalIndex, bool answer) external {
        // get goal
        GoalTokenStake memory goal = GoalTokenStakes[goalIndex];
        // get follower nft address
        address followerNFTAddress = getFollowerNFTAddress(goal.user);
        // check if msg.sender is following user (holds nft)
        require(
            IERC721(followerNFTAddress).balanceOf(msg.sender) > 0,
            "you are not following specified user"
        );
        // get end timestamp
        uint256 timestampEnd = goal.timestampEnd;
        // make sure voting window is opened
        require(
            block.timestamp >= timestampEnd &&
                block.timestamp < (timestampEnd + 86400),
            "voting window not opened/closed"
        );
        listIndexToVotesTokenStake[goalIndex].push(answer);
        emit GoalTokenStakeVote(msg.sender, answer, goalIndex);
    }

    function voteOnEtherStake(uint256 goalIndex, bool answer) external {
        // get goal
        GoalEtherStake memory goal = GoalEtherStakes[goalIndex];
        // get follower nft address
        address followerNFTAddress = getFollowerNFTAddress(goal.user);
        // check if msg.sender is following user (holds nft)
        require(
            IERC721(followerNFTAddress).balanceOf(msg.sender) > 0,
            "you are not following specified user"
        );
        // get end timestamp
        uint256 timestampEnd = goal.timestampEnd;
        // make sure voting window is opened
        require(
            block.timestamp >= timestampEnd &&
                block.timestamp < (timestampEnd + 86400),
            "voting window not opened/closed"
        );
        // add vote
        listIndexToVotesEtherStake[goalIndex].push(answer);
        emit GoalEtherStakeVote(msg.sender, answer, goalIndex);
    }

    function getBlockTimestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function getGoalEtherStake(
        uint256 index
    ) public view returns (GoalEtherStake memory) {
        return GoalEtherStakes[index];
    }

    function getGoalTokenStake(
        uint256 index
    ) public view returns (GoalTokenStake memory) {
        return GoalTokenStakes[index];
    }

    function getGoalEtherStakesByAddress(
        address user
    ) public view returns (GoalEtherStake[] memory) {
        return addressToGoalEtherStakes[user];
    }

    function getGoalTokenStakesByAddress(
        address user
    ) public view returns (GoalTokenStake[] memory) {
        return addressToGoalTokenStakes[user];
    }

    // chainlink checker function
    // chainlink runs this function every block
    // if return is true, chainlink will run state changing performUpkeep() function
    function checkUpkeep(
        bytes calldata /*checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        for (uint256 i; i < GoalEtherStakes.length; i++) {
            GoalEtherStake memory GES = GoalEtherStakes[i];
            if (block.timestamp > (GES.timestampEnd + 60 * 60 * 24)) {
                return (true, bytes("LensGoal"));
            }
            for (uint256 index; index < GoalEtherStakes.length; index++) {
                GoalTokenStake memory GTS = GoalTokenStakes[index];
                if (block.timestamp > (GTS.timestampEnd + 60 * 60 * 24)) {
                    return (true, bytes("LensGoal"));
                }
            }
            return (false, bytes("LensGoal"));
        }
    }

    // chainlink statechanging transaction
    // chainlink runs checkUpkeep function every block, if return is true performUpkeep function will be run
    function performUpkeep(bytes calldata /* performData */) external override {
        // iterate through all items in GoalEtherStakes
        for (uint256 i; i < GoalEtherStakes.length; i++) {
            // "GES" stands for "Goal Ether Stake"
            GoalEtherStake memory GES = GoalEtherStakes[i];
            uint256 listIndex = GES.listIndex;
            // check if voting window expired
            // (60*60*24 seconds is 1 day)
            if (block.timestamp > (GES.timestampEnd + 60 * 60 * 24)) {
                // calculate result of votes (see evaluateVotes() in LensGoalHelpers.sol)
                bool result = evaluateVotes(
                    listIndexToVotesEtherStake[listIndex]
                );
                // if result is true, ether is sent back to user
                if (result == true) {
                    transferEtherStakeBackToUser(GES);
                }
                if (result == false) {
                    transferEtherStakeToCommunityWallet(GES);
                }
            }
        }

        // iterate through all items in GoalTokenStakes[]
        // note: GTS = GoalTokenStake
        for (uint256 index; index < GoalTokenStakes.length; index++) {
            GoalTokenStake memory GTS = GoalTokenStakes[index];
            // get list index
            uint256 listIndex = GTS.listIndex;
            GoalTokenStake memory GES = GoalTokenStakes[index];
            // checks if current timestamp is one day after voting window opened
            if (block.timestamp > (GES.timestampEnd + 60 * 60 * 24)) {
                // gets result of votes
                bool result = evaluateVotes(
                    listIndexToVotesEtherStake[listIndex]
                );
                if (result == true) {
                    transferTokenStakeBackToUser(GTS);
                }
                if (result == false) {
                    transferTokenStakeToCommunityWallet(GTS);
                }
            }
        }
    }

    function transferEtherStakeBackToUser(GoalEtherStake memory GES) internal {
        payable(GES.user).transfer(GES.etherAmount);
    }

    function transferTokenStakeBackToUser(GoalTokenStake memory GTS) internal {
        IERC20(GTS.tokenAddress).transfer(GTS.user, GTS.tokenAmount);
    }

    function transferEtherStakeToCommunityWallet(
        GoalEtherStake memory GES
    ) internal {
        payable(communityWallet).transfer(GES.etherAmount);
    }

    function transferTokenStakeToCommunityWallet(
        GoalTokenStake memory GTS
    ) internal {
        IERC20(GTS.tokenAddress).transfer(communityWallet, GTS.tokenAmount);
    }

}

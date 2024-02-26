// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
//creating an Interface which is used as a framework to build upon. It defines the ERC-20 token standard functions required for interacting with tokens.
interface IERC20 {
    //we are using this function to be able to transfer tokens and we will be taking two inputs, amount and address
    function transfer(address, uint) external returns (bool);

 //we are creating the transfer from 
    function transferFrom(address, address, uint) external returns (bool);
}
 //syntax to create a contract. The contract manages crowdfunding campaigns with Ethereum-based tokens following the ERC-20 standard. 
contract CrowdFund {
    //we are creating an event to log important contract activities (notifying the front end)
    event Launch(
        //logs/emits the ID of the campaign
        uint id,
        //logs/emits the address of the creator
        address indexed creator,
        //logs/emits the amount we want to raise
        uint goal,
        //logs/emit the time the crowdfunding event is to be commenced
        uint32 startAt,
        //logs/emit the time the crowdfunding event will end
        uint32 endAt
    );


// event to enable the cancelation of the event
    event Cancel(uint id);
    //event pledge allows donators transfer tokens or donate 
    event Pledge(uint indexed id, address indexed caller, uint amount);
    //Unpledge enanles persons who no longer want to donate to call back the action
    event Unpledge(uint indexed id, address indexed caller, uint amount);
    //event claim enables the creator to withdraw the donated tokens
    event Claim(uint id);
    //event refund helps the donators get refunded
    event Refund(uint id, address indexed caller, uint amount);
 
 // we're using a struct to save what we have created
    struct Campaign {
        // Creator of campaign
        address creator;
        // Amount of tokens to raise
        uint goal;
        // Total amount pledged
        uint pledged;
        // Timestamp of start of campaign
        uint32 startAt;
        // Timestamp of end of campaign
        uint32 endAt;
        // True if goal was reached and creator has claimed the tokens.
        bool claimed;
    }
 
 //we are creating a link between the interface and the token we intend to use
    IERC20 public immutable token;
    //Keeps track of the total number of campaigns created.
    // It is also used to generate id for new campaigns.
    uint public count;
    // Maps campaign IDs to their corresponding Campaign struct
    mapping(uint => Campaign) public campaigns;
    // Maps campaign ID and pledger address to the amount pledged using nested mapping.
    mapping(uint => mapping(address => uint)) public pledgedAmount;
 
 //Initializes the contract with the ERC-20 token address, making it immutable.
    constructor(address _token) {
        //syncronizing the interface with the token which is the legal tender
        token = IERC20(_token);
    }
 
 //Allows users to create a new crowdfunding campaign with specified parameters
    function launch(uint _goal, uint32 _startAt, uint32 _endAt) external {
        //This condition ensures that the campaign starts in the future, preventing campaigns from being launched with past start times.
        require(_startAt >= block.timestamp, "start at < now");
        // This condition prevents campaigns from having an end time before the start time.
        require(_endAt >= _startAt, "end at < start at");
        //This prevents campaigns from having excessively long durations.
        require(_endAt <= block.timestamp + 90 days, "end at > max duration");
 
 // Increase the campaign count variable to generate a unique ID for the new campaign.
        count += 1;
        //Creates a new Campaign struct with the provided parameters and initializes it with the campaign details 
        campaigns[count] = Campaign({
            //address of the creator
            creator: msg.sender,
            //goal to be achieved
            goal: _goal,
            //total amount pledged
            pledged: 0,
            //start timestamp
            startAt: _startAt,
            //end timestamp
            endAt: _endAt,
            //status of the claim
            claimed: false
        });
 //emits a launch event log including the address of the creator, count, the goal, the start timestamp and the end timestamp.
        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }
 
    function cancel(uint _id) external {
        //Retrieves the campaign information associated with the provided _id from storage and stores it in storage as a reference 
        Campaign memory campaign = campaigns[_id];
        //this ensures that onluy the creator can cancel the campaign
        require(campaign.creator == msg.sender, "not creator");
        //this ensures that only campaigns that have not started can be canceled
        require(block.timestamp <= campaign.startAt, "started");
 //this is the final stage of cancelling the campaign if the two conditions above are met
        delete campaigns[_id];
        // Emits a cancel event to log the details of the cancel, including the campaign ID.
        emit Cancel(_id);
    }
 
    function pledge(uint _id, uint _amount) external {
        ////Retrieves the campaign information associated with the provided _id from storage and stores it in storage as a reference 
        Campaign storage campaign = campaigns[_id];
        //this ensures that the campaign has began before pledging commences if not a message saying not started will be emitted
        require(block.timestamp >= campaign.startAt, "not started");
        //this ensures that the campaign has not ended and that pledges can still be made
        require(block.timestamp <= campaign.endAt, "ended");
 //Increases the total pledged amount for the campaign by the specified _amount
        campaign.pledged += _amount;
        //Increases the pledged amount for the specific backer (msg.sender) and campaign by the specified _amount
        pledgedAmount[_id][msg.sender] += _amount;
        //Transfers the specified _amount of tokens from the sender using the transfer function of the ERC-20 token contract (token). 
        token.transferFrom(msg.sender, address(this), _amount);
 // Emits a pledge event to log the details of the pledge, including the campaign ID, the address of the caller (backer), and the amount pledged. 
        emit Pledge(_id, msg.sender, _amount);
    }
 
 //this function is designed to enable anyone who pledges and has a change of mind to unpledge
    function unpledge(uint _id, uint _amount) external {
//Retrieves the campaign information associated with the provided _id from storage and stores it in storage as a reference 
        Campaign storage campaign = campaigns[_id];
        //requires that the present time is less than when the event has ended if not it will emit a message saying the event has ended
        require(block.timestamp <= campaign.endAt, "ended");
 //Reduces the total pledged amount for the campaign by the specified _amount
        campaign.pledged -= _amount;
        //Reduces the pledged amount for the specific backer (msg.sender) and campaign by the specified _amount
        pledgedAmount[_id][msg.sender] -= _amount;
        //Transfers the specified _amount of tokens back to the backer (msg.sender) using the transfer function of the ERC-20 token contract (token). 
        token.transfer(msg.sender, _amount);
 // Emits an Unpledge event to log the details of the unpledge, including the campaign ID, the address of the caller (backer), and the amount unpledged. 
        emit Unpledge(_id, msg.sender, _amount);
    }
 //this function is designed to allow the creaator withdraw the pledged tokens
    function claim(uint _id) external {

        Campaign storage campaign = campaigns[_id];
        //ensures that only the creator can call this function
        require(campaign.creator == msg.sender, "not creator");
        //ensures that the claim can only be successful when the event has ended
        require(block.timestamp >= campaign.endAt, "not ended");
        //emits pledged<goal if the pledge is less than the goal
        require(campaign.pledged >= campaign.goal, "pledged < goal");
        //requires that the campaign goal has not been claimed otherwise it should emit claimed
        require(!campaign.claimed, "claimed");
 
        campaign.claimed = true;

        token.transfer(campaign.creator, campaign.pledged);
 //emits the ID of the claimed campaign
        emit Claim(_id);
    }
 /*This refund function is designed to allow backers to claim a refund for their pledged tokens
  if the crowdfunding campaign associated with a specific ID has ended, and the campaign did not reach its funding goal*/
    function refund(uint _id) external {
        /*It retrieves the campaign information associated with the provided _id from the campaigns mapping and stores 
        it in memory as a Campaign struct.*/
        Campaign memory campaign = campaigns[_id];
        //this require statements ensures that the current time is greater than the end timestamp if not it should emit that the event hasn't ended.
        require(block.timestamp >= campaign.endAt, "not ended");
        //this ensures that the total amount pledged is less than or equal to the goal
        require(campaign.pledged <= campaign.goal, "pledged >= goal");
 //Retrieves the amount of tokens pledged by the current caller (backer) for the specified campaign ID and stores it in the variable bal.
        uint bal = pledgedAmount[_id][msg.sender];
        //Sets the pledged amount for the current caller to zero, effectively marking that the backer has claimed their refund.
        pledgedAmount[_id][msg.sender] = 0;
        //Transfers the pledged tokens back to the caller using the transfer function of the ERC-20 token contract (token)
        token.transfer(msg.sender, bal);
        // Emits a Refund event to log the details of the refund, including the campaign ID, the address of the caller (backer), and the amount refunded.
        emit Refund(_id, msg.sender, bal);
    }
}
//0x0498B7c793D7432Cd9dB27fb02fc9cfdBAfA1Fd3  ERC20 wallet
/*1711108070 end 
 1708516070 start*/
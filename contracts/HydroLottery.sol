pragma solidity ^0.5.4;

import './HydroEscrow.sol';
import './HydroTokenTestnetInterface.sol';
import './IdentityRegistryInterface.sol';
import './RandomizerInterface.sol';

// Rinkeby testnet addresses
// HydroToken: 0x2df33c334146d3f2d9e09383605af8e3e379e180
// IdentityRegistry: 0xa7ba71305bE9b2DFEad947dc0E5730BA2ABd28EA
// Most recent HydroLottery deployed address: 0x001328288dd358644e289f48ec4ef0bc3139a2d2

// TODO check that the randomly generated number is within the valid range

/// @notice The Hydro Lottery smart contract to create decentralized lotteries for accounts that have an EIN Snowflake ID assciated with them. All payments are done in HYDRO instead of Ether.
/// @author Merunas Grincalaitis <merunasgrincalaitis@gmail.com>
contract HydroLottery {
    event LotteryStarted(uint256 indexed id, uint256 beginningDate, uint256 endDate);
    event LotteryEnded(uint256 indexed id, uint256 endTimestamp, uint256 einWinner);
    event Raffle(uint256 indexed lotteryId, bytes32 indexed queryId);

    struct Lottery {
        bool isFinished;
        bool exists;
    	uint256 id;
    	bytes32 name;
    	string description;
    	uint256 hydroPrice;
        uint256 hydroReward;
    	uint256 beginningDate;
    	uint256 endDate;
        uint256 einOwner; // Instead of using the address we use EIN for the owner of the lottery
    	// The escrow contract will setup a percentage of the funds raised for a fee that will be paid to the user that created the lottery or one he specifies
    	uint256 fee;
    	address feeReceiver;
    	address escrowContract;
        // The unique EINs of those that participate in this lottery. You can get the length of this array to calculate how many users are participating in this lottery
        uint256[] einsParticipating;
    	// Assigns a snowflakeId => tickedID which is a unique identifier for that participation. Only one ticket per EIN for now.
    	mapping(uint256 => uint256) assignedLotteries;
    	uint256 einWinner;
    }

    IdentityRegistryInterface public identityRegistry;
    HydroTokenTestnetInterface public hydroToken;
    RandomizerInterface public randomizer;

    // Lottery id => Lottery struct
    mapping(uint256 => Lottery) public lotteryById;
    Lottery[] public lotteries;
    uint256[] public lotteryIds;

    // Query ID for ending lotteries => Lottery ID to idenfity ending lotteries with oraclize's callback
    mapping(bytes32 => uint256) public endingLotteryIdByQueryId;

    // Escrow contract's address => lottery number
    mapping(address => uint256) public escrowContracts;
    address[] public escrowContractsArray;

    constructor(address _identityRegistryAddress, address _tokenAddress, address _randomizer) public {
        require(_identityRegistryAddress != address(0), 'The identity registry address is required');
        require(_tokenAddress != address(0), 'You must setup the token rinkeby address');
        require(_randomizer != address(0), 'You must setup the randomizer rinkeby address');
        hydroToken = HydroTokenTestnetInterface(_tokenAddress);
        identityRegistry = IdentityRegistryInterface(_identityRegistryAddress);
        randomizer = RandomizerInterface(_randomizer);
    }

    /// @notice Defines the lottery specification requires a HYDRO payment that will be used as escrow for this lottery. The escrow is a separate contract to hold people’s HYDRO funds not ether. Remember to approve() the right amount of HYDRO for this contract to set the hydro reward for the lottery.
    /// @param _name The lottery name
    /// @param _description What the lottery is about
    /// @param _hydroPricePerTicket How much each user has to pay to participate in the lottery, the price per ticket in HYDRO
    /// @param _hydroReward The HYDRO reward set by the owner of the lottery, the one that created it. Those are the tokens that the winner gets
    /// @param _beginningTimestamp When the lottery starts in timestamp
    /// @param _endTimestamp When the lottery ends in timestamp
    /// @param _fee The percentage from 0 to 100 that the owner takes for each ticket bought
    /// @param _feeReceiver The address that will receive the fee for each ticket bought
    /// @return uint256 Returns the new lottery identifier just created
    function createLottery(bytes32 _name, string memory _description, uint256 _hydroPricePerTicket, uint256 _hydroReward, uint256 _beginningTimestamp, uint256 _endTimestamp, uint256 _fee, address payable _feeReceiver) public returns(uint256) {
        uint256 newLotteryId = lotteries.length;

        require(identityRegistry.getEIN(msg.sender) != 0, 'The owner must have an EIN number');
        require(_fee >= 0 && _fee <= 100, 'The fee must be between 0 and 100 (in percentage without the % symbol)');
        require(hydroToken.balanceOf(msg.sender) >= _hydroReward, 'You must have enough token funds for the reward');
        require(_hydroReward > 0, 'The reward must be larger than zero');
        require( _endTimestamp > _beginningTimestamp, 'The lottery must end after the start not earlier');
        require(_feeReceiver != address(0), 'You need to specify the fee receiver even if its yourself');

        // Creating the escrow contract that will hold HYDRO tokens for this lottery exclusively as a safety feature
        HydroEscrow newEscrowContract = new HydroEscrow(_endTimestamp, address(hydroToken), _hydroReward, _fee, _feeReceiver);
        escrowContracts[address(newEscrowContract)] = newLotteryId;
        escrowContractsArray.push(address(newEscrowContract));

        uint256 allowance = hydroToken.allowance(msg.sender, address(this));
        // Transfer HYDRO tokens to the escrow contract from the msg.sender's address with transferFrom() until the lottery is finished
        // Use transferFrom() after the approval has been manually done. Checking the allowance first.
        require(allowance >= _hydroReward, 'Your allowance is not enough. You must approve() the right amount of HYDRO tokens for the reward.');
        require(hydroToken.transferFrom(msg.sender, address(newEscrowContract), _hydroReward), 'The token transfer must be successful');

        Lottery memory newLottery = Lottery({
            isFinished: false,
            exists: true,
            id: newLotteryId,
            name: _name,
            description: _description,
            hydroPrice: _hydroPricePerTicket,
            hydroReward: _hydroReward,
            beginningDate: _beginningTimestamp,
            endDate: _endTimestamp,
            einOwner: identityRegistry.getEIN(msg.sender),
            fee: _fee,
            feeReceiver: _feeReceiver,
            escrowContract: address(newEscrowContract),
            einsParticipating: new uint256[](0),
            einWinner: 0
        });

        lotteries.push(newLottery);
        lotteryById[newLotteryId] = newLottery;
        lotteryIds.push(newLotteryId);
        emit LotteryStarted(newLotteryId, _beginningTimestamp, _endTimestamp);
        return newLotteryId;
    }

    /// @notice Creates a unique participation ticket ID for a lottery and stores it inside the proper Lottery struct. You need to approve the right amount of tokens to this contract before buying the lottery ticket using your HYDRO tokens associated with your address. Note, you can only buy 1 ticket per lottery for now.
    /// @param _lotteryNumber The unique lottery identifier used with the mapping lotteryById
    /// @return uint256 Returns the ticket id that you just bought
    function buyTicket(uint256 _lotteryNumber) public returns(uint256) {
        uint256 ein = identityRegistry.getEIN(msg.sender);
        uint256 allowance = hydroToken.allowance(msg.sender, address(this));
        Lottery memory lottery = lotteryById[_lotteryNumber];
        uint256 ticketPrice = lottery.hydroPrice;
        address escrowContract = lottery.escrowContract;

        require(ein != 0, 'You must have an EIN snowflake identifier associated with your address when buying tickets');
        require(lottery.exists, 'The lottery must exist for you to participate in it by buying a ticket');
        require(now < lottery.endDate, 'The time to participate in the lottery is finished');
        require(allowance >= ticketPrice, 'Your allowance is not enough. You must approve() the right amount of HYDRO tokens for the price of this lottery ticket.');
        require(hydroToken.transferFrom(msg.sender, escrowContract, ticketPrice), 'The ticket purchase for this lottery must be successful when transfering tokens');

        // Update the lottery parameters
        uint256 ticketId = lotteryById[_lotteryNumber].einsParticipating.length;
        lotteryById[_lotteryNumber].einsParticipating.push(ticketId);
        lotteryById[_lotteryNumber].assignedLotteries[ein] = ticketId;

        return ticketId;
    }

    /// @notice Randomly selects one Snowflake ID associated to a lottery as the winner of the lottery and must be called by the owner of the lottery when the endDate is reached or later
    function raffle(uint256 _lotteryNumber) public payable {
        Lottery memory lottery = lotteryById[_lotteryNumber];
        uint256 senderEIN = identityRegistry.getEIN(msg.sender);

        require(!lottery.isFinished, 'The raffle for this lottery has been completed already');
        require(senderEIN == lottery.einOwner, 'The raffle must be executed by the owner of the lottery');
        require(msg.value >= 0.01 ether, 'You must send at least 0.01 ether to execute the termination function');
        require(now > lottery.endDate, 'You must wait until the lottery end date is reached before selecting the winner');

        uint256 numberOfParticipants = lottery.einsParticipating.length;
        bytes32 queryId = randomizer.startGeneratingRandom.value(msg.value)(numberOfParticipants); // The randomizer generates a number between 0 and the number of participants
        endingLotteryIdByQueryId[queryId] = _lotteryNumber;
        emit Raffle(_lotteryNumber, queryId);
    }

    /// @notice Can only be executed by the Randomizer contract. It select a winner for a given lottery number and query id.
    /// @param _queryId The query ID used to generated the random number
    /// @param _randomNumber The random number generated through oraclize
    function endLottery(bytes32 _queryId, uint256 _randomNumber) public {
        require(msg.sender == address(randomizer), 'The lottery can only be ended by the randomizer for selecting a random winner');
        uint256 lotteryId = endingLotteryIdByQueryId[_queryId];
        
        // Select the winner based on his position in the array of participants
        uint256 einWinner = lotteryById[lotteryId].einsParticipating[_randomNumber];
        lotteryById[lotteryId].einWinner = einWinner;
        lotteryById[lotteryId].isFinished = true;
        emit LotteryEnded(lotteryId, now, einWinner);
    }

    /// @notice Returns all the lottery ids
    /// @return uint256[] The array of all lottery ids
    function getLotteryIds() public view returns(uint256[] memory) {
        return lotteryIds;
    }

    /// @notice To get the ticketId given the lottery and ein
    /// @param lotteryId The id of the lottery
    /// @param ein The ein of the user that purchased the ticket
    /// @return ticketId The Id of the ticket purchased, zero is also a valid identifier if there are more than 1 tickets purchased
    function getTicketIdByEin(uint256 lotteryId, uint256 ein) public view returns(uint256 ticketId) {
        ticketId = lotteryById[lotteryId].assignedLotteries[ein];
    }

    /// @notice To get the array of eins participating in a lottery
    /// @param lotteryId The id of the lottery that you want to examine
    /// @return uint256[] The array of EINs participating in the lottery that have purchased a ticket
    function getEinsParticipatingInLottery(uint256 lotteryId) public view returns(uint256[] memory) {
        return lotteryById[lotteryId].einsParticipating;
    }
}

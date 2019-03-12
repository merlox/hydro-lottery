pragma solidity ^0.5.4;

contract HydroEscrow {
    uint256 public endTimestamp;
    address public hydroLotteryAddress;
    uint256 public hydroReward;
    uint256 public fee;
    address payable public feeReceiver;
    HydroTokenTestnetInterface public hydroToken;

    modifier onlyHydroLottery() {
        require(msg.sender == hydroLotteryAddress, 'This function can only be executed by the original HydroLottery');
        _;
    }

    // To set all the initial variables
    constructor(uint256 _endTimestamp, address _hydroToken, uint256 _hydroReward, uint256 _fee, address payable _feeReceiver) public {
        require(_endTimestamp > now, 'The lottery must end after now');
        require(_hydroToken != address(0), 'You must set the token address');
        require(_hydroReward > 0, 'The reward must be larger than zero HYDRO tokens');
        require(_fee >= 0 && _fee <= 100, 'The fee must be between 0 and 100 (in percentage without the % symbol)');
        require(_feeReceiver != address(0), 'You must set a fee receiver');
        endTimestamp = _endTimestamp;
        hydroLotteryAddress = msg.sender;
        hydroToken = HydroTokenTestnetInterface(_hydroToken);
        hydroReward = _hydroReward;
        fee = _fee;
        feeReceiver = _feeReceiver;
    }

    // To send the reward to the winner and distribute the corresponding fee to the fee receiver
    function releaseWinnerReward(address _winner) public onlyHydroLottery {
        require(now >= endTimestamp, 'You can only release funds after the lottery has ended');
        uint256 hydroInsideThisContract = hydroToken.balanceOf(address(this));
        uint256 hydroForFeeReceiver;
        uint256 hydroForWinner;

        // If there is no fee, the winner gets all including the ticket prices accomulated + the standard reward, if there's a fee, the winner gets his reward + the ticket prices accomulated - the fee percentage
        if(fee == 0) {
            hydroForFeeReceiver = 0;
            hydroForWinner = hydroInsideThisContract;
        } else {
            hydroForFeeReceiver = hydroInsideThisContract * (fee / 100);
            hydroForWinner = hydroInsideThisContract - hydroForFeeReceiver;
        }

        hydroToken.transfer(_winner, hydroForWinner);
        hydroToken.transfer(feeReceiver, hydroForFeeReceiver);
    }
}

contract HydroLottery {
    event LotteryStarted(uint256 indexed id, uint256 beginningDate, uint256 endDate);
    event LotteryEnded(uint256 indexed id, uint256 endTimestamp, uint256 einWinner);
    event Raffle(uint256 indexed lotteryId, bytes32 indexed queryId);

    struct Lottery {
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

        require(lottery.einWinner == 0, 'The raffle for this lottery has been completed already');
        require(now > lottery.endDate, 'You must wait until the lottery end date is reached before selecting the winner');
        require(senderEIN == lottery.einOwner, 'The raffle must be executed by the owner of the lottery');

        bytes32 queryId = randomizer.startGeneratingRandom.value(msg.value)();
        endingLotteryIdByQueryId[queryId] = _lotteryNumber;
        emit Raffle(_lotteryNumber, queryId);
    }

    /// @notice Can only be executed by the Randomizer contract. It select a winner for a given lottery number and query id.
    /// @param _queryId The query ID used to generated the random number
    /// @param _randomNumber The random number generated through oraclize
    function endLottery(bytes32 _queryId, uint256 _randomNumber) public {
        require(msg.sender == address(randomizer), 'The lottery can only be ended by the randomizer for selecting a random winner');

        uint256 maxRandomValue = 1e10 - 1;
        uint256 lotteryId = endingLotteryIdByQueryId[_queryId];
        uint256 numberOfParticipants = lotteryById[lotteryId].einsParticipating.length;

        // Map the ranges from the maximum random number to the number of participants
        uint256 indexWinner = mapRanges(_randomNumber, 0, maxRandomValue, 0, numberOfParticipants);

        // Just to make sure that we're generating the right values
        require(indexWinner <= numberOfParticipants, 'The generated number must be equal or less the number of participants');

        // Select the winner based on his position in the array of participants
        uint256 einWinner = lotteryById[lotteryId].einsParticipating[indexWinner];
        lotteryById[lotteryId].einWinner = einWinner;
        emit LotteryEnded(lotteryId, now, einWinner);
    }

    /// @notice Maps a range to another and returns the scaled value
    function mapRanges(uint256 value, uint256 fromMin, uint256 fromMax, uint256 toMin, uint256 toMax) public view returns(uint256) {
        uint256 fromSpan = fromMax - fromMin;
        uint256 toSpan = toMax - toMin;
        uint256 valueScaled = (value - fromMin) / fromSpan;
        return toMin + (valueScaled * toSpan);
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

contract HydroTokenTestnetInterface {
    function transfer(address _to, uint256 _amount) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success);
    function doTransfer(address _from, address _to, uint _amount) internal;
    function balanceOf(address _owner) public view returns (uint256 balance);
    function approve(address _spender, uint256 _amount) public returns (bool success);
    function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success);
    function burn(uint256 _value) public;
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);
    function totalSupply() public view returns (uint);
    function setRaindropAddress(address _raindrop) public;
    function authenticate(uint _value, uint _challenge, uint _partnerId) public;
    function setBalances(address[] memory _addressList, uint[] memory _amounts) public;
    function getMoreTokens() public;
}

interface IdentityRegistryInterface {
    function isSigned(address _address, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s)
        external pure returns (bool);

    // Identity View Functions /////////////////////////////////////////////////////////////////////////////////////////
    function identityExists(uint ein) external view returns (bool);
    function hasIdentity(address _address) external view returns (bool);
    function getEIN(address _address) external view returns (uint ein);
    function isAssociatedAddressFor(uint ein, address _address) external view returns (bool);
    function isProviderFor(uint ein, address provider) external view returns (bool);
    function isResolverFor(uint ein, address resolver) external view returns (bool);
    function getIdentity(uint ein) external view returns (
        address recoveryAddress,
        address[] memory associatedAddresses, address[] memory providers, address[] memory resolvers
    );

    // Identity Management Functions ///////////////////////////////////////////////////////////////////////////////////
    function createIdentity(address recoveryAddress, address[] calldata providers, address[] calldata resolvers)
        external returns (uint ein);
    function createIdentityDelegated(
        address recoveryAddress, address associatedAddress, address[] calldata providers, address[] calldata resolvers,
        uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external returns (uint ein);
    function addAssociatedAddress(
        address approvingAddress, address addressToAdd, uint8 v, bytes32 r, bytes32 s, uint timestamp
    ) external;
    function addAssociatedAddressDelegated(
        address approvingAddress, address addressToAdd,
        uint8[2] calldata v, bytes32[2] calldata r, bytes32[2] calldata s, uint[2] calldata timestamp
    ) external;
    function removeAssociatedAddress() external;
    function removeAssociatedAddressDelegated(address addressToRemove, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        external;
    function addProviders(address[] calldata providers) external;
    function addProvidersFor(uint ein, address[] calldata providers) external;
    function removeProviders(address[] calldata providers) external;
    function removeProvidersFor(uint ein, address[] calldata providers) external;
    function addResolvers(address[] calldata resolvers) external;
    function addResolversFor(uint ein, address[] calldata resolvers) external;
    function removeResolvers(address[] calldata resolvers) external;
    function removeResolversFor(uint ein, address[] calldata resolvers) external;

    // Recovery Management Functions ///////////////////////////////////////////////////////////////////////////////////
    function triggerRecoveryAddressChange(address newRecoveryAddress) external;
    function triggerRecoveryAddressChangeFor(uint ein, address newRecoveryAddress) external;
    function triggerRecovery(uint ein, address newAssociatedAddress, uint8 v, bytes32 r, bytes32 s, uint timestamp)
        external;
    function triggerDestruction(
        uint ein, address[] calldata firstChunk, address[] calldata lastChunk, bool resetResolvers
    ) external;
}

interface RandomizerInterface {
    function setHydroLottery(address _hydroLottery) external;
    function startGeneratingRandom() external payable returns(bytes32 queryId);
    function __callback(bytes32 _queryId, string calldata  _result, bytes calldata _proof) external;
}

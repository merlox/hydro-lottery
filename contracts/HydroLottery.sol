pragma solidity ^0.5.0;

import './HydroEscrow.sol';
import './HydroTokenTestnetInterface.sol';
import './IdentityRegistryInterface.sol';
import './OraclizeAPI.sol';

// Rinkeby testnet addresses
// HydroToken: 0x2df33c334146d3f2d9e09383605af8e3e379e180
// IdentityRegistry: 0xa7ba71305bE9b2DFEad947dc0E5730BA2ABd28EA
// Most recent HydroLottery deployed address: 0x001328288dd358644e289f48ec4ef0bc3139a2d2

// TODO Uncomment oraclize constructor

/// @notice The Hydro Lottery smart contract to create decentralized lotteries for accounts that have an EIN Snowflake ID assciated with them. All payments are done in HYDRO instead of Ether.
/// @author Merunas Grincalaitis <merunasgrincalaitis@gmail.com>
contract HydroLottery is usingOraclize {
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
    	// Assigns a snowflakeId => tickedID which is a unique identifier for that participation
    	mapping(uint256 => uint256) assignedLotteries;
    	uint256 einWinner;
    }

    IdentityRegistryInterface public identityRegistry;
    HydroTokenTestnetInterface public hydroToken;

    // Lottery id => Lottery struct
    mapping(uint256 => Lottery) public lotteryById;
    Lottery[] public lotteries;
    uint256[] public lotteryIds;

    // Escrow contract's address => lottery number
    mapping(address => uint256) public escrowContracts;
    address[] public escrowContractsArray;

    constructor(address _identityRegistryAddress, address _tokenAddress) public {
        require(_identityRegistryAddress != address(0), 'The identity registry address is required');
        require(_tokenAddress != address(0), 'You must setup the token rinkeby address');
        hydroToken = HydroTokenTestnetInterface(_tokenAddress);
        identityRegistry = IdentityRegistryInterface(_identityRegistryAddress);
        // TODO Uncomment this when the contract is completed
        /* oraclize_setProof(proofType_Ledger); */
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
        require(_beginningTimestamp >= now, 'The lottery must start now or in the future');
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

        return newLotteryId;
    }

    /// @notice Creates a unique participation ticket ID for a lottery and stores it inside the proper Lottery struct. You need to approve the right amount of tokens to this contract before buying the lottery ticket using your HYDRO tokens associated with your address.
    /// @param _lotteryNumber The unique lottery identifier used with the mapping lotteryById
    /// @return uint256 Returns the ticket id that you just bought
    function buyTicket(uint256 _lotteryNumber) public returns(uint256) {
        uint256 ein = identityRegistry.getEIN(msg.sender);
        uint256 allowance = hydroToken.allowance(msg.sender, address(this));
        uint256 ticketPrice = lotteryById[_lotteryNumber].hydroPrice;

        require(ein != 0, 'You must have an EIN snowflake identifier associated with your address when buying tickets');
        require(lotteryById[_lotteryNumber].exists, 'The lottery must exist for you to participate in it by buying a ticket');
        require(allowance >= ticketPrice, 'Your allowance is not enough. You must approve() the right amount of HYDRO tokens for the price of this lottery ticket.');
        require(hydroToken.transferFrom(msg.sender, address(newEscrowContract), _hydroReward), 'The ticket purchase for this lottery must be successful when transfering tokens');

        // TODO check that the user sends the required amount of HYDRO to participate by reading the Lottery fee and checking the HYDRO sent
        uint256 ticketId = lotteryById[_lotteryNumber].einsParticipating.length;
        lotteryById[_lotteryNumber].assignedLotteries;

        /* lotteryById[_lotteryNumber].einsParticipating.push(_einSnowflake);
        lotteryById[_lotteryNumber].assignedLotteries[_einSnowflake] = ticketId; */
        return ticketId;
    }

    // Assigns a Snowflake ID to a lottery ID
    function assignSnowflakeIdToLotteryId(uint256 _snowflakeId, uint256 _lotteryId) public {}

    // Randomly selects one Snowflake ID associated to a lottery, can be called several times
    function raffle(uint256 _lotteryNumber) public returns(uint256 snoflakeIdWinner) {

    }

    /// @notice Generates a random number between 1 and 10 both inclusive.
    /// Must be payable because oraclize needs gas to generate a random number.
    /// Can only be executed when the game ends.
    function generateNumberWinner() internal {
      uint256 numberRandomBytes = 7;
      uint256 delay = 0;
      uint256 callbackGas = 200000;

      bytes32 queryId = oraclize_newRandomDSQuery(delay, numberRandomBytes, callbackGas);
    }

   /// @notice Callback function that gets called by oraclize when the random number is generated
   /// @param _queryId The query id that was generated to proofVerify
   /// @param _result String that contains the number generated
   /// @param _proof A string with a proof code to verify the authenticity of the number generation
   function __callback(
      bytes32 _queryId,
      string memory  _result,
      bytes memory _proof
   ) public oraclize_randomDS_proofVerify(_queryId, _result, _proof) {

      // Checks that the sender of this callback was in fact oraclize
      assert(msg.sender == oraclize_cbAddress());

      uint256 numberWinner = (uint256(keccak256(bytes(_result)))%10+1);
      distributePrizes();
   }

   function distributePrizes() internal {

   }

   /// Returns all the lottery ids
   function getLotteryIds() public view returns(uint256[] memory) {
       return lotteryIds;
   }
}

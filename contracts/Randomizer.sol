pragma solidity ^0.5.0;

import './HydroLotteryInterface.sol';
import './usingOraclize.sol';

// Remember to setup the address of the hydroLottery contract before using it

// Create a contract that inherits oraclize and has the address of the hydro lottery
// A function that returns the query id and generates a random id which calls the hydro lottery
contract Randomizer is usingOraclize {
    HydroLotteryInterface public hydroLottery;
    address public owner;

    modifier onlyOwner {
        require(msg.sender == owner, 'This function can only be executed by the owner of the contract');
        _;
    }

    modifier onlyHydroLottery {
        require(msg.sender == address(hydroLottery), 'This function can only be executed by the Hydro Lottery smart contract');
        _;
    }

    constructor () public {
        // TODO uncomment this since we can't have it when testing with ganache
        /* oraclize_setProof(proofType_Ledger); */
        owner = msg.sender;
    }

    /// @notice Set the address of the hydro lottery contract for communicating with it later
    /// @param _hydroLottery The address of the lottery contract
    function setHydroLottery(address _hydroLottery) public onlyOwner {
        require(_hydroLottery != address(0), 'The hydro lottery address can only be set by the owner of this contract');
        hydroLottery = HydroLotteryInterface(_hydroLottery);
    }

    /// @notice Starts the process of ending a lottery by executing the function that generates random numbers from oraclize
    /// @return queryId The queryId identifier to associate a lottery ID with a query ID
    function startGeneratingRandom() public payable onlyHydroLottery returns(bytes32 queryId) {
        // TODO check that the number generated is between 0 and the desired range
        uint256 numberRandomBytes = 20;
        uint256 delay = 0;
        uint256 callbackGas = 2e6; // 2 million gas for the callback function so that it has more than enough gas

        queryId = oraclize_newRandomDSQuery(delay, numberRandomBytes, callbackGas);
    }

   /// @notice Callback function that gets called by oraclize when the random number is generated
   /// @param _queryId The query id that was generated to proofVerify
   /// @param _result String that contains the number generated
   /// @param _proof A string with a proof code to verify the authenticity of the number generation
   function __callback(
      bytes32 _queryId,
      string memory _result,
      bytes memory _proof
   ) public oraclize_randomDS_proofVerify(_queryId, _result, _proof) {

      // Checks that the sender of this callback was in fact oraclize
      require(msg.sender == oraclize_cbAddress(), 'The callback function can only be executed by oraclize');

      // Generates a number between 0 and 1 billion - 1
      uint256 generatedRandomNumber = (uint256(keccak256(bytes(_result))) % 1e10);
      hydroLottery.endLottery(_queryId, generatedRandomNumber);
   }
}

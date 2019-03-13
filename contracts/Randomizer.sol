pragma solidity ^0.5.4;

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
        oraclize_setProof(proofType_Ledger);
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
    function startGeneratingRandom(uint256 _maxNumber) public payable onlyHydroLottery {
        require(msg.value >= 0.01 ether, 'You must send at least 0.01 for processing the ending functionality');
        oraclize_query("WolframAlpha", strConcat("random number between 0 and ", uint2str(_maxNumber)));
    }

   /// @notice Callback function that gets called by oraclize when the random number is generated
   /// @param _queryId The query id that was generated to proofVerify
   /// @param _result String that contains the number generated
   /// @param _proof A string with a proof code to verify the authenticity of the number generation
   function __callback(
      bytes32 _queryId,
      string memory _result,
      bytes memory _proof
   ) public {
      require(msg.sender == oraclize_cbAddress(), 'The callback function can only be executed by oraclize');
      hydroLottery.endLottery(_queryId, parseInt(_result, 10));
   }
}

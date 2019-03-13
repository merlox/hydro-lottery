pragma solidity ^0.5.4;

import './usingOraclize.sol';

// Create a contract that inherits oraclize and has the address of the hydro lottery
// A function that returns the query id and generates a random id which calls the hydro lottery
contract RandomizerTest is usingOraclize {
    event ShowRandomResult(string message, uint256 result, uint256 digits);
    event Called(string message);

    // Query ID => digits how many digits each random number has for each queryId
    mapping(bytes32 => uint256) public originalMaxNumber;

    constructor () public {
        OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        oraclize_setProof(proofType_Ledger);
    }

    /// @notice Starts the process of ending a lottery by executing the function that generates random numbers from oraclize
    function startGeneratingRandom(uint256 _maxNumber) public payable {
        emit Called('The function has been called');

        bytes32 queryId = oraclize_query("WolframAlpha", strConcat("random number between 0 and ", uint2str(_maxNumber)));
        originalMaxNumber[queryId] = _maxNumber;
    }

   /// @notice Callback function that gets called by oraclize when the random number is generated
   /// @param _queryId The query id that was generated to proofVerify
   /// @param result String that contains the number generated
   function __callback(
      bytes32 _queryId,
      string memory result,
      bytes memory proof
   ) public {
      // Checks that the sender of this callback was in fact oraclize
      require(msg.sender == oraclize_cbAddress(), 'The callback function can only be executed by oraclize');
      emit ShowRandomResult('Merunas message', parseInt(result), originalMaxNumber[_queryId]);
   }
}

pragma solidity ^0.5.4;

import './usingOraclize.sol';

// Create a contract that inherits oraclize and has the address of the hydro lottery
// A function that returns the query id and generates a random id which calls the hydro lottery
contract RandomizerTest is usingOraclize {
    event ShowRandomResult(string message, string result);
    event Called(string message);

    constructor () public {
        /* OAR = OraclizeAddrResolverI(0x0F7868921060Bf4c01D4f9d1179A4e16A01B3dAC); */
        oraclize_setProof(proofType_Ledger);
    }

    /// @notice Starts the process of ending a lottery by executing the function that generates random numbers from oraclize
    function startGeneratingRandom() public payable {
        emit Called('The function has been called');
        oraclize_query("WolframAlpha", "random number between 1 and 100");
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
      emit ShowRandomResult('Merunas message', result);
   }
}

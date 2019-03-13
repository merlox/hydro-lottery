pragma solidity ^0.5.4;

import './usingOraclize.sol';

// Remember to setup the address of the hydroLottery contract before using it

// Create a contract that inherits oraclize and has the address of the hydro lottery
// A function that returns the query id and generates a random id which calls the hydro lottery
contract RandomizerTest is usingOraclize {
    event ShowRandomResult(string message, string result, string message2, uint256 generatedNumber, string message3, uint256 generatedCutNumber);
    address public owner;

    constructor () public {
        OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        oraclize_setProof(proofType_Ledger);
    }

    /// @notice Starts the process of ending a lottery by executing the function that generates random numbers from oraclize
    /// @return queryId The queryId identifier to associate a lottery ID with a query ID
    function startGeneratingRandom() public payable returns(bytes32 queryId) {
        // TODO check that the number generated is between 0 and the desired range
        uint256 numberRandomBytes = 5;
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

      uint256 generatedRandomNumber = uint256(keccak256(bytes(_result)));
      uint256 generatedCutNumber = (uint256(keccak256(bytes(_result)))%10+1);

      emit ShowRandomResult('Merunas message', _result, 'Second message', generatedRandomNumber, 'Third message', generatedCutNumber);
   }
}

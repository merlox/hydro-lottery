pragma solidity ^0.5.4;

interface RandomizerInterface {
    event GeneratedRandom(bytes32 _queryId, uint256 _numberOfParticipants, uint256 _generatedRandomNumber);
    event QueryRandom(string message);

    function setHydroLottery(address _hydroLottery) external;
    function startGeneratingRandom(uint256 _maxNumber) external payable returns(bytes32);
    function __callback(bytes32 _queryId, string calldata  _result, bytes calldata _proof) external;
}

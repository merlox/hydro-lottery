pragma solidity ^0.5.0;

interface RandomizerInterface {
    function setHydroLottery(address _hydroLottery) external;
    function startGeneratingRandom() external returns(bytes32 queryId);
    function __callback(bytes32 _queryId, string memory  _result, bytes memory _proof) external;
}

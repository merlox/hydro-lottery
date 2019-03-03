pragma solidity ^0.5.0;

interface HydroLotteryInterface {
    function createLottery(bytes32 _name, string memory _description, uint256 _hydroPricePerTicket, uint256 _hydroReward, uint256 _beginningTimestamp, uint256 _endTimestamp, uint256 _fee, address payable _feeReceiver) external returns(uint256);
    function buyTicket(uint256 _lotteryNumber) external returns(uint256);
    function raffle(uint256 _lotteryNumber) external;
    function endLottery(bytes32 _queryId, uint256 _randomNumber) external;
}

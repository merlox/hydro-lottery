pragma solidity ^0.5.4;

interface HydroLotteryInterface {
    event LotteryStarted(uint256 indexed id, uint256 beginningDate, uint256 endDate);
    event LotteryEnded(uint256 indexed id, uint256 endTimestamp, uint256 einWinner);
    event Raffle(uint256 indexed lotteryId, bytes32 indexed queryId);

    function createLottery(bytes32 _name, string calldata _description, uint256 _hydroPricePerTicket, uint256 _hydroReward, uint256 _beginningTimestamp, uint256 _endTimestamp, uint256 _fee, address payable _feeReceiver) external returns(uint256);
    function buyTicket(uint256 _lotteryNumber) external returns(uint256);
    function raffle(uint256 _lotteryNumber) external;
    function endLottery(bytes32 _queryId, uint256 _randomNumber) external;
    function getLotteryIds() external view returns(uint256[] memory);
    function getTicketIdByEin(uint256 lotteryId, uint256 ein) external view returns(uint256 ticketId);
    function getEinsParticipatingInLottery(uint256 lotteryId) external view returns(uint256[] memory);
}

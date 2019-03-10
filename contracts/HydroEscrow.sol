pragma solidity ^0.5.4;

import './HydroTokenTestnetInterface.sol';

// Latest deployed working sample: 0x448Db81E994fF4F0e94c46cF573ea16734B78703

/// @notice Stores HYDRO inside as an escrow for lotteries. This contracts stores the initial reward set by the lottery creator and the ticket funds that users pay to participate in the lottery, then it distributes rewards and the corresponding fee to the fee receiver.
/// @author Merunas Grincalaitis <merunasgrincalaitis@gmail.com>
contract HydroEscrow {
    uint256 public endTimestamp;
    address public hydroLotteryAddress;
    uint256 public hydroReward;
    uint256 public fee;
    address payable public feeReceiver;
    HydroTokenTestnetInterface public hydroToken;

    modifier onlyHydroLottery() {
        require(msg.sender == hydroLotteryAddress, 'This function can only be executed by the original HydroLottery');
        _;
    }

    // To set all the initial variables
    constructor(uint256 _endTimestamp, address _hydroToken, uint256 _hydroReward, uint256 _fee, address payable _feeReceiver) public {
        require(_endTimestamp > now, 'The lottery must end after now');
        require(_hydroToken != address(0), 'You must set the token address');
        require(_hydroReward > 0, 'The reward must be larger than zero HYDRO tokens');
        require(_fee >= 0 && _fee <= 100, 'The fee must be between 0 and 100 (in percentage without the % symbol)');
        require(_feeReceiver != address(0), 'You must set a fee receiver');
        endTimestamp = _endTimestamp;
        hydroLotteryAddress = msg.sender;
        hydroToken = HydroTokenTestnetInterface(_hydroToken);
        hydroReward = _hydroReward;
        fee = _fee;
        feeReceiver = _feeReceiver;
    }

    // To send the reward to the winner and distribute the corresponding fee to the fee receiver
    function releaseWinnerReward(address _winner) public onlyHydroLottery {
        require(now >= endTimestamp, 'You can only release funds after the lottery has ended');
        uint256 hydroInsideThisContract = hydroToken.balanceOf(address(this));
        uint256 hydroForFeeReceiver;
        uint256 hydroForWinner;

        // If there is no fee, the winner gets all including the ticket prices accomulated + the standard reward, if there's a fee, the winner gets his reward + the ticket prices accomulated - the fee percentage
        if(fee == 0) {
            hydroForFeeReceiver = 0;
            hydroForWinner = hydroInsideThisContract;
        } else {
            hydroForFeeReceiver = hydroInsideThisContract * (fee / 100);
            hydroForWinner = hydroInsideThisContract - hydroForFeeReceiver;
        }

        hydroToken.transfer(_winner, hydroForWinner);
        hydroToken.transfer(feeReceiver, hydroForFeeReceiver);
    }
}

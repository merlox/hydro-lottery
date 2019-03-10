pragma solidity ^0.5.4;
// NOTE: Delegacall does NOT update state of the receiving contract!!
// Try to update the state with delegatecall -> call -> to contract since call() does indeed update the storage
// 1. Deploy Something, then Middleware, then HydroLottery
// 2. Run start() from HydroLottery and check if the state in Something has been updated
// 3. Check the sender address received if it's the original or the contract one

/// @notice This is a test contract to see if delegatecall works and if the return values are right. Turns out it works
/// @author Merunas Grincalaitis <merunasgrincalaitis@gmail.com>
contract HydroLottery {
    event SupPeople(bool, bytes);

    function start(address contractAddress, uint256 myNumber) public {
        (bool transferResult, bytes memory transferResultData) = contractAddress.delegatecall(abi.encodeWithSignature('byPassWithCall(uint256)', myNumber));
        emit SupPeople(transferResult, transferResultData);
    }
}

contract Middleware {
    address public somethingAddress;

    constructor (address _somethingAddress) public {
        somethingAddress = _somethingAddress;
    }

    // Passes the transaction to the other contract with call()
    function byPassWithCall(uint256 _myNumber) public returns(bytes memory) {
        (bool transferResult, bytes memory transferResultData) = somethingAddress.call(abi.encodeWithSignature('doSomething(uint256)', _myNumber));
        return transferResultData;
    }
}

// Can you convert bytes to uint256? No you can't in solidity but you can use parseInt() to convert it in javascript
contract Something {
    event Transfer(address _sender, uint256 _amount);
    uint256 public myVariable = 5;

    function doSomething(uint256 myNumber) public returns(address) {
        myVariable += myNumber;
        emit Transfer(msg.sender, myNumber);
        return msg.sender;
    }
}

pragma solidity ^0.5.4;

contract HydroTokenTestnetInterface {
    function transfer(address _to, uint256 _amount) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success);
    function doTransfer(address _from, address _to, uint _amount) internal;
    function balanceOf(address _owner) public view returns (uint256 balance);
    function approve(address _spender, uint256 _amount) public returns (bool success);
    function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success);
    function burn(uint256 _value) public;
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);
    function totalSupply() public view returns (uint);
    function setRaindropAddress(address _raindrop) public;
    function authenticate(uint _value, uint _challenge, uint _partnerId) public;
    function setBalances(address[] memory _addressList, uint[] memory _amounts) public;
    function getMoreTokens() public;
}

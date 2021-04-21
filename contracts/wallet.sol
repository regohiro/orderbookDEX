// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract Wallet is Ownable{
  using SafeMath for uint256;

  struct Token {
    bytes32 ticker;
    address tokenAddress;
  }
  mapping(bytes32 => Token) public tokenMapping;
  bytes32[] public tokenList; //id for tokens

  //supports multiple tokens
  //address: account, bytes32: ticker symbol, uint256: balance
  mapping(address => mapping(bytes32 => uint256)) public balances;

  modifier tokenExist(bytes32 _ticker){
    require(tokenMapping[_ticker].tokenAddress != address(0), "Token does not exist");
    _;
  }

  function addToken(bytes32 _ticker, address _tokenAddress) external onlyOwner{
    tokenMapping[_ticker] = Token(_ticker, _tokenAddress);
    tokenList.push(_ticker);
  }

  function getBalance(bytes32 _ticker) view external tokenExist(_ticker) returns(uint256){
    return balances[msg.sender][_ticker];
  }

  //only for testing purpose
  function cleanWallet(bytes32 _ticker) external tokenExist(_ticker) onlyOwner{ 
    balances[msg.sender][_ticker] = 0;
  }

  function deposit(uint _amount, bytes32 _ticker) payable external tokenExist(_ticker){
    balances[msg.sender][_ticker] = balances[msg.sender][_ticker].add(_amount);
    IERC20(tokenMapping[_ticker].tokenAddress).transferFrom(msg.sender, address(this), _amount);
  }

  function withdraw(uint _amount, bytes32 _ticker) external tokenExist(_ticker){
    require(balances[msg.sender][_ticker] >= _amount, "Balance not sufficient");

    balances[msg.sender][_ticker] = balances[msg.sender][_ticker].sub(_amount);
    IERC20(tokenMapping[_ticker].tokenAddress).transfer(msg.sender, _amount);
  }

  function depositEth() payable external {
    balances[msg.sender][bytes32("ETH")] = balances[msg.sender][bytes32("ETH")].add(msg.value);
  }
    
  function withdrawEth(uint _amount) external {
    require(balances[msg.sender][bytes32("ETH")] >= _amount,'Insuffient balance'); 
    balances[msg.sender][bytes32("ETH")] = balances[msg.sender][bytes32("ETH")].sub(_amount);
    (bool success, ) = payable(msg.sender).call{value:_amount}("");
    if(!success) balances[msg.sender][bytes32("ETH")] = balances[msg.sender][bytes32("ETH")].add(_amount);
  }
    
}

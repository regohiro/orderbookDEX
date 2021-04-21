// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./wallet.sol";

contract Dex is Wallet{
  using SafeMath for uint;

  enum Side {
    BUY,
    SELL
  }

  struct Order {
    uint id;
    address trader;
    Side side;
    bytes32 ticker;
    uint amount;
    uint price;
    uint filled;
  }

  uint public nextOrderId = 0;

  mapping(bytes32 => mapping(uint8 => Order[])) public orderBook;

  function getOrderBook(bytes32 _ticker, Side _side) view public returns(Order[] memory){
    return orderBook[_ticker][uint8(_side)];
  }

  function cleanOrderBook(bytes32 _ticker, Side _side) public { //only for testing purpose
    Order[] storage orders = orderBook[_ticker][uint8(_side)];
    while(orders.length > 0){
      orders.pop();
    }
  }

  function createLimitOrder(Side _side, bytes32 _ticker, uint _amount, uint _price) public{
    if(_side == Side.BUY){
      require(balances[msg.sender]["ETH"] >= _amount.mul(_price));
    }else if(_side == Side.SELL){
      require(balances[msg.sender][_ticker] >= _amount);
    }

    Order[] storage orders = orderBook[_ticker][uint8(_side)];
    orders.push(Order(nextOrderId, msg.sender, _side, _ticker, _amount, _price, 0));
    nextOrderId++;

    uint n = orders.length;
    if(_side == Side.BUY){
      for(uint i=n-1;i>0;i--){ 
        if(orders[i].price > orders[i-1].price){
          Order memory tmp = orders[i];
          orders[i] = orders[i-1];
          orders[i-1] = tmp;
        }else{
          break;
        }
      }
    }else if(_side == Side.SELL){
      for(uint i=n-1;i>0;i--){
        if(orders[i].price < orders[i-1].price){
          Order memory tmp = orders[i];
          orders[i] = orders[i-1];
          orders[i-1] = tmp;
        }else{
          break;
        }
      }
    }
  }

  function cancelLimitOrder(Side _side, bytes32 _ticker) public {
    Order[] storage orders = orderBook[_ticker][uint8(_side)];
    bool didOrder = false;
    //Delete cancelled orders and shift orderbook
    for(uint i=0; i<orders.length; ){
      if(orders[i].trader == msg.sender){
        didOrder = true;
        for(uint j=i; j<orders.length-1; j++){
          orders[j] = orders[j+1];
        }
        orders.pop();
      }else{
        i++;
      }
    }
    require(didOrder, "No orders were submitted");
  }

  function createMarketOrder(Side _side, bytes32 _ticker, uint _amount) public{
    Order[] storage orders = orderBook[_ticker][_side==Side.BUY ? 1 : 0];

    uint totalFilled = 0;
    
    if(_side == Side.BUY){
      require(balances[msg.sender]["ETH"] > 0, "insufficient balance");
    }else{
      require(balances[msg.sender][_ticker] >= _amount, "insufficient balance");
    }

    for(uint i=0; i < orders.length && totalFilled < _amount; i++){
      //How much we can fill from order[i]
      if(totalFilled + orders[i].amount >= _amount){
        orders[i].filled += _amount - totalFilled;
      }else{
        orders[i].filled += orders[i].amount;
      }

      //Update totalFilled;
      totalFilled += orders[i].filled;
      orders[i].amount -= orders[i].filled;

      //Execute the trade & shift balances between buyer/seller
      if(_side == Side.BUY){
        //Verify that the buyer has enough ETH to cover the purchase (require)
        require(balances[msg.sender]["ETH"] >= orders[i].filled*orders[i].price, "insufficient balance");
        balances[msg.sender]["ETH"] -= orders[i].filled*orders[i].price;
        balances[msg.sender][_ticker] += orders[i].filled;
        balances[orders[i].trader]["ETH"] += orders[i].filled*orders[i].price;
        balances[orders[i].trader][_ticker] -= orders[i].filled;
      }else{
        //Verify that the seller has enough _ticker to cover the purchase (require)
        require(balances[msg.sender][_ticker] >= orders[i].filled, "insufficient balance");
        balances[msg.sender][_ticker] -= orders[i].filled;
        balances[msg.sender]["ETH"] += orders[i].filled*orders[i].price;
        balances[orders[i].trader][_ticker] += orders[i].filled;
        balances[orders[i].trader]["ETH"] -= orders[i].filled*orders[i].price;
      }
    }

    if(orders.length != 0){
      //Loop through the orderbook and remove 100% filled orders
      uint numOfFilledOrders = 0;
      for(uint i=0; i < orders.length && orders[i].amount == 0;i++){
        numOfFilledOrders++;
      }
      for(uint i=0; numOfFilledOrders!=0 && i<orders.length-numOfFilledOrders; i++){
        orders[i] = orders[i+numOfFilledOrders];
      }
      for(uint i=1; i <= numOfFilledOrders; i++){
        orders.pop();
      }
    }
  }

}


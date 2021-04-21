const Dex = artifacts.require("Dex");
const Link = artifacts.require("Link");
const truffleAssert = require('truffle-assertions');

const LINK = web3.utils.fromUtf8("LINK");

contract("Dex", accounts => {
  let dex;
  let link;
  let orderbook;

  before(async function(){
    dex = await Dex.deployed();
    link = await Link.deployed();
    await dex.addToken(LINK, link.address, {from: accounts[0]});
  });
  
  it("should throw an error if ETH balance is too low when creating BUY limit order", async () => {
    await truffleAssert.reverts(
      dex.createLimitOrder(0, LINK, 10, 1)
    );
    dex.depositEth({value: 10});
    await truffleAssert.passes(
      dex.createLimitOrder(0, LINK, 10, 1)
    );
  });

  it("should throw an error if token balance is too low when creating SELL limit order", async () => {
    await truffleAssert.reverts(
      dex.createLimitOrder(1, LINK, 10, 1)
    );
    await link.approve(dex.address, 500);
    await dex.deposit(10, LINK);
    await truffleAssert.passes(
      dex.createLimitOrder(1, LINK, 10, 1)
    );
  });

  it("The BUY order book should be ordered on price from highest to lowest starting at index 0", async () => {
    await dex.depositEth({value: 3000});
    await dex.createLimitOrder(0, LINK, 1, 300); 
    await dex.createLimitOrder(0, LINK, 1, 100);
    await dex.createLimitOrder(0, LINK, 1, 200);

    orderbook = await dex.getOrderBook(LINK, 0);
    assert(orderbook.length > 0);
    for (let i = 0; i < orderbook.length - 1; i++) {
      assert(orderbook[i].price >= orderbook[i+1].price, "not right order in buy book");
    }
  });

  it("The SELL order book should be ordered on price from lowest to highest starting at index 0", async () => {
    await dex.createLimitOrder(1, LINK, 1, 300);
    await dex.createLimitOrder(1, LINK, 1, 100);
    await dex.createLimitOrder(1, LINK, 1, 200);

    orderbook = await dex.getOrderBook(LINK, 1);
    assert(orderbook.length > 0);

    for (let i = 0; i < orderbook.length - 1; i++) {
      assert(orderbook[i].price <= orderbook[i+1].price, "not right order in sell book")
    }
  });

  /*Limit order cancel feature*/
  it("Order has to be submitted before cancelling the order", async () => {
    await dex.cleanOrderBook(LINK, 1);
    await truffleAssert.reverts(
      dex.cancelLimitOrder(1, LINK)
    );
  });

  it("Cancelled trader's order should not remain in the orderbook", async () => {
    await dex.createLimitOrder(1, LINK, 1, 300);
    await dex.createLimitOrder(1, LINK, 1, 100);
    await dex.createLimitOrder(1, LINK, 1, 200);
    
    dex.cancelLimitOrder(1, LINK)
    orderbook = await dex.getOrderBook(LINK, 1);
    assert.equal(orderbook.length, 0);
  });

  it("Other account's order should remain, in the right order", async () => {
    orderbook = await dex.getOrderBook(LINK, 1);
    assert(orderbook.length == 0, "The SELL orderbook should be empty");

    //Send LINK tokens to accounts 1, 2, 3 from account 0
    await link.transfer(accounts[1], 150);
    await link.transfer(accounts[2], 150);
    await link.transfer(accounts[3], 150);
    //Approve DEX for accounts 1, 2, 3
    await link.approve(dex.address, 50, {from: accounts[1]});
    await link.approve(dex.address, 50, {from: accounts[2]});
    await link.approve(dex.address, 50, {from: accounts[3]});
    //Deposit LINK into DEX for accounts 1, 2, 3
    await dex.deposit(50, LINK, {from: accounts[1]});
    await dex.deposit(50, LINK, {from: accounts[2]});
    await dex.deposit(50, LINK, {from: accounts[3]});
    //Fill up the sell order book
    await dex.createLimitOrder(1, LINK, 5, 100, {from: accounts[1]});
    await dex.createLimitOrder(1, LINK, 5, 200, {from: accounts[2]});
    await dex.createLimitOrder(1, LINK, 5, 400, {from: accounts[2]});
    await dex.createLimitOrder(1, LINK, 5, 300, {from: accounts[3]});

    dex.cancelLimitOrder(1, LINK, {from:accounts[2]});
    orderbook = await dex.getOrderBook(LINK, 1);
    assert(
      orderbook[0].price == 100 &&
      orderbook[0].trader == accounts[1] &&
      orderbook[1].price == 300 &&
      orderbook[1].trader == accounts[3] 
    );
  });

});


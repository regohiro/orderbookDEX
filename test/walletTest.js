const Dex = artifacts.require("Dex");
const Link = artifacts.require("Link");
const truffleAssert = require('truffle-assertions');

const LINK = web3.utils.fromUtf8("LINK");

contract.skip("Dex", accounts => {
  let dex;
  let link;

  before(async () => {
    dex = await Dex.deployed();
    link = await Link.deployed();
  });

  it("should only be possible for owners to add tokens", async ()=>{
    await truffleAssert.passes(
      dex.addToken(LINK, link.address, {from: accounts[0]})
    );
    await truffleAssert.reverts(
      dex.addToken(LINK, link.address, {from: accounts[1]})
    );
  });

  it("should handle deposit correctly", async ()=>{
    await link.approve(dex.address, 500);
    await dex.deposit(100, LINK);
    let balance = await dex.balances(accounts[0], LINK);
    assert.equal(balance.toNumber(), 100)
  });

  it("should handle faulty withdraws correctly", async ()=>{
    await truffleAssert.reverts(
      dex.withdraw(500, LINK)
    );
  });

  it("should handle correct withdraws correctly", async ()=>{
    await truffleAssert.passes(
      dex.withdraw(100, LINK)
    );
  });

});
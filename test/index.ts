import { BigNumberish } from "@ethersproject/bignumber";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { GameApi__factory, GameApi } from "../typechain";

const revertMessages = {

  wrongFeeToOpenSession: "Need to pay the right fee.",

  openDoubleSession: "Active session already exists.",

  leaveNonExistingSession: "Cannot leave empty session.",
  
  notEnoughLinkForChainLink: "Not enough LINK - fill contract with faucet",

};

describe("Game Contract", async function () {

  let GameApi:GameApi__factory; 
  let gameApi:GameApi;

  // Mocks
  
  let owner:SignerWithAddress;
  let addr1:SignerWithAddress;
  let addr2:SignerWithAddress;
  let addrs:SignerWithAddress[];

  const openSessionFee: BigNumberish = 7;

  this.beforeEach(async function () {
    
    GameApi = await ethers.getContractFactory("GameApi");

    let LinkToken = await ethers.getContractFactory("Link");
    
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    
    gameApi = await GameApi.deploy(openSessionFee);

  });

  describe("Testing opening and close sessions", function () {

    it("Function openSession should pass when the right fee is paid.", async function () {
    
      await gameApi.openSession({value: openSessionFee});
      
      expect(await gameApi.getCreatedSessionsCounter()).to.equal(1);
  
    });

    it("When opening a session the session's counter should increment.", async function () {
      
      await gameApi.openSession({value: openSessionFee});

      expect(await gameApi.getCreatedSessionsCounter()).to.eq(1);
      
      await gameApi.connect(addr1).openSession({value: openSessionFee});

      expect(await gameApi.getCreatedSessionsCounter()).to.eq(2);

    });

    it("Player can't open a session when the fee is not provided.", async function () {

      await expect(gameApi.openSession())
        .to.be.revertedWith(revertMessages.wrongFeeToOpenSession);
  
    });
  
    it("Player can't open a session when fee is lower than expected.", async function () {
  
      await expect(gameApi.openSession({value: openSessionFee - 1}))
        .to.be.revertedWith(revertMessages.wrongFeeToOpenSession);
  
    });

    it("Player can't open a session when there is one already active", async function () {

      await gameApi.connect(addr2).openSession({value: openSessionFee});
  
      await expect(gameApi.connect(addr2).openSession({value: openSessionFee}))
        .to.be.revertedWith(revertMessages.openDoubleSession);
  
    });
  
    it("Function closeSession fails when the user has no session active", async function () {

      await expect(gameApi.closeSession())
        .to.be.revertedWith(revertMessages.leaveNonExistingSession);
  
    });

    it("When player has no active session isPlayerPlaying should return false", async function () {
  
      const isPlayerPlaying: boolean = await gameApi.isPlayerPlaying(owner.address)
  
      expect(isPlayerPlaying).is.false;
  
    });
  
    it("When player has active session isPlayerPlaying should return true", async function () {
  
      await gameApi.openSession({value: openSessionFee});
  
      const isPlayerPlaying: boolean = await gameApi.isPlayerPlaying(owner.address)
  
      expect(isPlayerPlaying).is.true;
  
    });

    it("Player when owns an active session he can close it.", async function () {

      await gameApi.openSession({value: openSessionFee});
  
      const playing = await gameApi.isPlayerPlaying(owner.address);
  
      expect(playing).is.true;
  
      await gameApi.closeSession();
  
      const closed = await gameApi.isPlayerPlaying(owner.address);
  
      expect(closed).is.false;
      
    });

  });

  describe("Testing emmitted events", function (){

    it("When player opens session event PlayerOpenSession is emitted.", async function () {
  
      await expect(gameApi.openSession({value: openSessionFee}))
        .to.emit(gameApi, "PlayerOpenSession")
        .withArgs(owner.address, 1);
  
    });
  
    it("When player closes session event PlayerClosesSession is emitted.", async function () {
  
      await gameApi.openSession({value: openSessionFee})

      await expect(gameApi.closeSession())
        .to.emit(gameApi, "PlayerClosesSession")
        .withArgs(owner.address, 1);
  
    });


  });

  describe.only("Testing playing feature", function () {
    
    it("Players can't play if the game contract does't has enough link", async function () {

      await gameApi.openSession({value: openSessionFee});
  
      await expect(gameApi.play(1)).to.be.revertedWith(revertMessages.notEnoughLinkForChainLink);
      
    });

  });

});

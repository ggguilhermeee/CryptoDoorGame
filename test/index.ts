import { BigNumberish } from "@ethersproject/bignumber";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { GameApi__factory, GameApi, LinkToken__factory, LinkToken, VRFConsumerBase__factory, VRFConsumerBase, VRFCoordinatorV2__factory, VRFCoordinatorV2, VRFCoordinator__factory, VRFCoordinator, ExposedGameLogic, ExposedGameLogic__factory } from "../typechain";

const revertMessages = {

  wrongFeeToOpenSession: "Need to pay the right fee.",

  openDoubleSession: "Active session already exists.",

  leaveNonExistingSession: "Cannot leave empty session.",
  
  notEnoughLinkForChainLink: "Not enough LINK - fill contract with faucet",

  playWithNoActiveSession: "No session active to play.",

  doublingRequestRandomness: "Already requested a random number.",

  nonExistingDoor: "You choosed non-existing door.",

};

describe("Game Contract", async function () {

  let GameApi:GameApi__factory; 
  let gameApi:GameApi;

  let ExposedGameLogic:ExposedGameLogic__factory;
  let exposedGameLogic:ExposedGameLogic;

  // Mocks

  let LinkToken:LinkToken__factory;
  let linkToken:LinkToken;

  let VRFCoordinator:VRFCoordinator__factory;
  let vrfCoordinator:VRFCoordinator;

  //-----

  let owner:SignerWithAddress;
  let addr1:SignerWithAddress;
  let addr2:SignerWithAddress;
  let addrs:SignerWithAddress[];

  const openSessionFee: BigNumberish = 7;

  this.beforeEach(async function () {
    
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Game chain of contracts
    GameApi = await ethers.getContractFactory("GameApi");
    ExposedGameLogic = await ethers.getContractFactory("ExposedGameLogic");

    // Mocks
    LinkToken = await ethers.getContractFactory("LinkToken");
    linkToken = await LinkToken.deploy();
    
    VRFCoordinator = await ethers.getContractFactory("VRFCoordinator");
    vrfCoordinator = await VRFCoordinator.deploy(linkToken.address, owner.address)
    // ----

    gameApi = await GameApi.deploy(openSessionFee, vrfCoordinator.address, linkToken.address, 1, ethers.utils.formatBytes32String("test"));
    exposedGameLogic = await ExposedGameLogic.deploy(openSessionFee, vrfCoordinator.address, linkToken.address, 1, ethers.utils.formatBytes32String("test"));

  });

  async function sendLinkToGameContract(amount:number){
    const transferLinkTransaction = await linkToken.transfer(gameApi.address, amount);
    await transferLinkTransaction.wait();
  }

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

    it("When player starts new session the session level and round is set to 1", async function () {

      await gameApi.openSession({value: openSessionFee});

      

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

  describe("Testing internal functions", function () {

    it("The number of doors per level is defined by the formula (f - c) + 2", async function () {

      const result = (f:number, c:number) => (f-c) + 2;

      const finalLevel = (await exposedGameLogic.getFinalLevel()).toNumber();

      expect(await exposedGameLogic.getNumberOfDoorByLevel(1)).to.be.eq(result(finalLevel, 1));
      expect(await exposedGameLogic.getNumberOfDoorByLevel(5)).to.be.eq(result(finalLevel, 5));
      expect(await exposedGameLogic.getNumberOfDoorByLevel(finalLevel)).to.be.eq(result(finalLevel, finalLevel));

    });

    // TODO
    it("The key for rewards map state is composed by encodePacked(session, level)", async function () {

      const session = 1;
      const level = 2;

      //const keyLookup = session + level;
      //const expectedKey = ethers.utils.keccak256(keyLookup);
    

      console.log(await exposedGameLogic.getRewardsKey(session, level));
      
    });

  });

  describe("Testing playing feature", function () {
    
    it("Players can't play if the game contract does't has enough link", async function () {

      await expect(gameApi.play(1)).to.be.revertedWith(revertMessages.notEnoughLinkForChainLink);
      
    });

    it("Player can't play with no active session", async function () {

      await sendLinkToGameContract(100);
      
      await expect(gameApi.play(1)).to.be.revertedWith(revertMessages.playWithNoActiveSession);

    });

    it("Player can't play again while the randomness is not fullfilled", async function (){

      await sendLinkToGameContract(100);

      await gameApi.openSession({value: openSessionFee});

      await gameApi.play(1);

      await expect(gameApi.play(1)).to.be.revertedWith(revertMessages.doublingRequestRandomness);

    });

    it("Player can't choose a door number 0 or bigger than the doors per level", async function (){

      await sendLinkToGameContract(100);

      await gameApi.openSession({value: openSessionFee});

      const doorsAmount = (await exposedGameLogic.getNumberOfDoorByLevel(1)).toNumber();

      await expect(gameApi.play(0)).to.be.revertedWith(revertMessages.nonExistingDoor);

      await expect(gameApi.play(doorsAmount + 1)).to.be.revertedWith(revertMessages.nonExistingDoor);

    });

  });

});

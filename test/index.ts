import { BigNumberish } from "@ethersproject/bignumber";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { GameLogic, GameLogic__factory } from "../typechain";

describe("GameLogic", function () {

  let GameLogic:GameLogic__factory; 
  let gameLogic:GameLogic;
  
  let owner:SignerWithAddress;
  let addr1:SignerWithAddress;
  let addr2:SignerWithAddress;
  let addrs:SignerWithAddress[];

  const startSessionFee: BigNumberish = 7;

  before(async function () {
    GameLogic = await ethers.getContractFactory("GameLogic");

    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    gameLogic = await GameLogic.deploy(startSessionFee);

  });

  this.beforeEach(async function () {
    try{
      await gameLogic.leaveSession();
      await gameLogic.connect(addr1).leaveSession();
    }catch{}
  });

  describe("Getter Mechanics Logic", function () {
    
    it("Function startGameSession should fail when fee is not paid.", async function () {

      await expect(gameLogic.startGameSession()).to.be.revertedWith("Need to pay the right fee.");

    });

    it("Function startGameSession should fail when payed fee is lower than the fee in storage.", async function () {

      await expect(gameLogic.startGameSession({value: startSessionFee - 1})).to.be.revertedWith("Need to pay the right fee.");

    });

    it("Function startGameSession should fail when payed fee is bigger than the fee in storage.", async function () {
      
      await expect(gameLogic.startGameSession({value: startSessionFee + 1})).to.be.revertedWith("Need to pay the right fee.");
    
    });
    
    it("Function startGameSession should pass when the right fee is paid.", async function () {
      console.log(await gameLogic.isPlayerPlaying(owner.address));
      
      const response = await gameLogic.startGameSession({value: startSessionFee});

      expect(response.v).greaterThan(0);

    });

    it("Function startGameSession should fail when user is already has active session.", async function () {

      gameLogic.connect(addr2).startGameSession({value: startSessionFee});

      await expect(gameLogic.connect(addr2).startGameSession({value: startSessionFee}))
        .to.be.revertedWith("Active session already exists.");

    });

    it("Function isPlayerPlaying should return false when user is not in a session.", async function () {
    
      const isPlayerPlaying: boolean = await gameLogic.isPlayerPlaying(owner.address)
  
      expect(isPlayerPlaying).is.false;

    });
  
    it("Fuction isPlayerPlaying should return true when user starts a new session.", async function () {
  
      await gameLogic.startGameSession({value: startSessionFee});

      const isPlayerPlaying: boolean = await gameLogic.isPlayerPlaying(owner.address)
  
      expect(isPlayerPlaying).is.true;

    });

    //it("Function isPlayerPlaying when succeded increments a counter used as new game session id", async function (){});

    // leaves session
    //it("Function leaveSession fails when the user has no session active", async function (){});
    //it("Function leaveSession completes when the user has one session active", async function (){});
  })

});

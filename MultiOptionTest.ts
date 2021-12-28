import { expect, use } from "chai";
import { upgrades, ethers } from "hardhat";
import { Contract, Signer } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import DfynToken from "../artifacts/contracts/DfynTest.sol/DfynToken.json";
import GameQuestion from "../artifacts/contracts/GameQuestion.sol/GameQuestion.json";
import MultiOption from "yoda-prediction-contracts\test\MultiOptionTest.ts"

use(solidity);

const encodedID = (id: string) => ethers.utils.keccak256(ethers.utils.toUtf8Bytes(id));

describe("Factory Upgradable", () => {
  //const [owner, admin, operator, user] = new MockProvider().getWallets();
  let owner;
  let admin;
  let operator;
  let user;
  let user1;
  let user2;
  before(async () => {
    const signers = await ethers.getSigners();
    owner = signers[0];
    admin = signers[1];
    operator = signers[2];
    user = signers[3];
    user1 = signers[4];
    user2 = signers[5];
  });

  let dfynTokenContract;
  let dfynToken;
  let questionFactoryContract;
  let questionFactory;
  let multiOptionContract;
  let multiOptionProxy;
  let multiOptionImplementation;

  //console.log(encodedGameId)

  let data1;
  let questionData;


  beforeEach(async () => {
    dfynTokenContract = await ethers.getContractFactory("DfynToken");
    dfynToken = await dfynTokenContract.connect(user).deploy(4000);
    await dfynToken.transfer(user1.address, 1000, { from: user.address });
    await dfynToken.transfer(user2.address, 1000, { from: user.address });

    questionFactoryContract = await ethers.getContractFactory("Factory");
    questionFactory = await upgrades.deployProxy(questionFactoryContract, [admin.address, operator.address], {
      kind: "uups",
    });

    multiOptionContract = await ethers.getContractFactory("GameQuestion");

    const params = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "uint256", "uint256", "uint8", "uint8", "address", "bytes32"],
      [3, 1632049420, 1635600093, 90, 10, dfynToken.address, encodedID("G1Q1")],
    );

    multiOptionProxy = await upgrades.deployProxy(multiOptionContract, [params, admin.address]);
    await multiOptionProxy.deployed();

    //Storing implemen

    multiOptionImplementation = await upgrades.erc1967.getImplementationAddress(multiOptionProxy.address);
    await questionFactory.connect(admin).addQuestionType(encodedID("I1"), multiOptionImplementation);

    data1 = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "uint256", "uint256", "uint8", "uint8", "address", "bytes32"],
      [3, 1632049420, 1635600093, 90, 10, dfynToken.address, encodedID("G1Q1")],
    );

    questionData = [
      {
        gameID: encodedID("G1"),
        questionID: encodedID("G1Q1"),
        data: data1,
      },
      ];
  });
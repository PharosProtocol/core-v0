
import { ethers } from "hardhat";
import { expect } from "chai";
import '@types/jest';


describe("SoloAccount", function () {
  it("should do something", async function () {
    const SoloAccount = await ethers.getContractFactory("SoloAccount");
    const soloAccount = await SoloAccount.deploy();
    await soloAccount.deployed();
    
    // Now you can interact with the `SoloAccount` contract.
    // For example, you can call a function and check the result:
    // const result = await iAssessor.someFunction();
    // expect(result).to.equal(expectedResult);
  });
});

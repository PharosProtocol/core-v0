import { expect } from "chai";
import { ethers } from 'ethers';
import hre from "hardhat";
import { time } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("Lock", function () {
  it("Should set the right unlockTime", async function () {
    const lockedAmount = 1_000_000_000;
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

    // deploy a lock contract where funds can be withdrawn
    // one year in the future
    const lock = await ethers.deployContract("Lock", [unlockTime], {
      value: lockedAmount,
    });

    // assert that the value is correct
    expect(await lock.unlockTime()).to.equal(unlockTime);
  });
});
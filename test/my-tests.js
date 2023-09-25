"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const chai_1 = require("chai");
const ethers_1 = require("ethers");
const network_helpers_1 = require("@nomicfoundation/hardhat-toolbox/network-helpers");
describe("Lock", function () {
    it("Should set the right unlockTime", function () {
        return __awaiter(this, void 0, void 0, function* () {
            const lockedAmount = 1000000000;
            const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
            const unlockTime = (yield network_helpers_1.time.latest()) + ONE_YEAR_IN_SECS;
            // deploy a lock contract where funds can be withdrawn
            // one year in the future
            const lock = yield ethers_1.ethers.deployContract("Lock", [unlockTime], {
                value: lockedAmount,
            });
            // assert that the value is correct
            (0, chai_1.expect)(yield lock.unlockTime()).to.equal(unlockTime);
        });
    });
});

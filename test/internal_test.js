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
const hardhat_1 = require("hardhat");
describe("SoloAccount", function () {
    it("should do something", function () {
        return __awaiter(this, void 0, void 0, function* () {
            const SoloAccount = yield hardhat_1.ethers.getContractFactory("SoloAccount");
            const soloAccount = yield SoloAccount.deploy();
            yield soloAccount.deployed();
            // Now you can interact with the `SoloAccount` contract.
            // For example, you can call a function and check the result:
            // const result = await iAssessor.someFunction();
            // expect(result).to.equal(expectedResult);
        });
    });
});

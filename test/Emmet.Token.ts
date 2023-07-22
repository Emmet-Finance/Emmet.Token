import {
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Emmet.Token", function () {

    const NAME = "EMMET";
    const SYMBOL = NAME;

    async function deployEmmetToken() {
        // Extract hardhat accounts
        const [owner, otherAccount] = await ethers.getSigners();
        // Deploy a contract instance
        const EmmetToken = await ethers.getContractFactory("EmmetToken");
        const token = await EmmetToken.deploy(otherAccount, owner);
        // Return the handlers
        return { token, owner, otherAccount }
    }

    describe("Start Emmet.Token Tests", function () {

        it("Should deploy the contract", async function () {
            const { token, owner, otherAccount } = await loadFixture(deployEmmetToken);
            // 1. The owner should have 750M tokens
            expect(await token.balanceOf(owner)).to.equal(750_000_000n * 10n ** 18n)
            // 2. The vault should have 250M tokens
            expect(await token.balanceOf(otherAccount)).to.equal(250_000_000n * 10n ** 18n)
            // 3. Total supply should equal 1 bn
            expect(await token.totalSupply()).to.equal(1_000_000_000n * 10n ** 18n)
            // 4. The name should equal `NAME`
            expect(await token.name()).to.equal(NAME);
            // 5. The Symbol should equal `SYMBOL`
            expect(await token.symbol()).to.equal(SYMBOL);
            // 6. Decimals should equal 18
            expect(await token.decimals()).to.equal(18n);
        });

        it("Owners can burn their tokens", async function () {
            const { token, owner, otherAccount } = await loadFixture(deployEmmetToken);
            // 1. The vault should have 250 M
            expect(await token.balanceOf(otherAccount)).to.equal(250_000_000n * 10n ** 18n)
            // 2. The vault burns all the tokens
            await token.connect(otherAccount).burn(250_000_000n * 10n ** 18n);
            // 3. The vault should have 0 tokens
            expect(await token.balanceOf(otherAccount)).to.equal(0n)
            // 4. The balance must remain 750 M
            expect(await token.totalSupply()).to.equal(750_000_000n * 10n ** 18n)
        });
    })

})
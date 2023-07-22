import {
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Emet.Vesting", function(){

    async function deployContracts() {
        // Extract hardhat accounts
        const [owner, otherAccount] = await ethers.getSigners();

        // Deploy a token contract instance
        const EmmetToken = await ethers.getContractFactory("EmmetToken");
        const token = await EmmetToken.deploy(otherAccount, otherAccount);

        // Deploy a vesting contract instance
        const EmmetVesting = await ethers.getContractFactory("EmmetVesting");
        const vesting = await EmmetVesting.deploy(await token.getAddress(), otherAccount);

        // Return the handlers
        return { token, vesting, owner, otherAccount }
    }

    describe("Start Emet.Vesting Testing", function() {

        it("Should Deploy", async function() {
            const { token, vesting } = await loadFixture(deployContracts);
            // The address of `emmetToken` must equal token.getAddress()
            expect(await vesting.emmetToken()).to.equal(await token.getAddress());
            // halfYear muts equal 15811200 seconds
            expect(await vesting.halfYear()).to.equal(15811200n);
        });

        it("Should NOT add Beneficiary - No Allowance", async function(){
            const { vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // Add owner as beneficiary
            await expect(vesting.connect(otherAccount).addBeneficiary(owner.address, 250000000n,1n,1n))
                .to.be.revertedWithCustomError(vesting,"AmountError")
                .withArgs(250000000n, "Available Token allowance", 0);
        });

        it("Should add Beneficiary", async function(){
            const { token, vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // The otherAccount should have a balance of 1 bn
            expect(await token.balanceOf(otherAccount)).to.equal(1000000000n * 10n**18n);
            // Approve in the token contract
            await token.connect(otherAccount).approve(await vesting.getAddress(), 250000000n * 10n**18n);
            // Add owner as beneficiary
            await vesting.connect(otherAccount).addBeneficiary(owner.address, 250000000n * 10n**18n,1n,1n);
            // Check the beneficiary was added
            expect((await vesting.connect(owner).getBeneficiary(owner.address)).allocated)
            .to.equal(250000000000000000000000000n);
        });

        
    });
});
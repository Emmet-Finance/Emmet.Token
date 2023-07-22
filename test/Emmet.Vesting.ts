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
            // Check the beneficiary was added & 250M allocated
            expect((await vesting.connect(owner).getBeneficiary(owner.address)).allocated)
            .to.equal(250000000000000000000000000n);
            // Check allocated()
            expect(await vesting.connect(owner).allocated()).to.equal(250000000000000000000000000n);
            // Check available()
            expect(await vesting.connect(owner).available()).to.equal(0n);
            // Check cliff()
            const cliff = await vesting.connect(owner).cliff();
            console.log("Cliff", cliff)
            const elapsed = await vesting.connect(owner).timeElapsed();
            console.log("Elasped:", elapsed);
            console.log("elapsed <= _cliff", elapsed <= cliff)
            expect(cliff).to.equal(15811200n);
            // Ceck getVesting()
            expect(await vesting.connect(owner).getVesting()).to.equal(63244800n);
            // Check unwithdrawn()
            expect(await vesting.connect(owner).unwithdrawn()).to.equal(250000000000000000000000000n);
            // Check withdrawn()
            expect(await vesting.connect(owner).withdrawn()).to.equal(0n);
        });

        it("Admin should update CFO, Token, Admin", async function() {
            const { token, vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // Update admin
            await vesting.connect(owner).updateAdmin(otherAccount.address);
            // The new admin shoud update CFO
            await vesting.connect(otherAccount).updateCFO(owner.address);
            // Update Token address
            await vesting.connect(otherAccount).updateTokenContract(await token.getAddress());
            // Transfer tokens to the `owner` account
            await token.connect(otherAccount).transfer(owner.address, 250000000000000000000000000n);
            // Approve
            await token.connect(owner).approve(await vesting.getAddress(), 250000000000000000000000000n);
            // The new CFO should add a beneficiary
            await vesting.connect(owner).addBeneficiary(otherAccount.address, 250000000000000000000000000n, 1n, 1n);
            // The beneficiary should see their allocation
            expect(await vesting.connect(otherAccount).allocated()).to.equal(250000000000000000000000000n);
        });

        it("Admin updates Beneficiary, Beneficiary withdraws", async function(){
            const { token, vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // The otherAccount should have a balance of 1 bn
            expect(await token.balanceOf(otherAccount)).to.equal(1000000000n * 10n**18n);
            // Approve in the token contract
            await token.connect(otherAccount).approve(await vesting.getAddress(), 250000000n * 10n**18n);
            // Add owner as beneficiary
            await vesting.connect(otherAccount).addBeneficiary(owner.address, 250000000n * 10n**18n,1n,1n);
            // Check beneficiary has allocation
            expect(await vesting.connect(owner).allocated()).to.equal(250000000000000000000000000n);
            // Admin updates the Beneficiary
            await vesting.connect(owner).updateBeneficiary(owner.address, {
                allocated:250000000000000000000000000n,
                withdrawn:0n,
                start:0n, // This was changed to enable withdraw
                cliff:0n, // This was changed to enable withdraw
                vesting:0n // This was changed to enable withdraw
            });
            // Now available() should equal allocated()
            const allocated = await vesting.connect(owner).allocated();
            expect(allocated).to.equal(250000000000000000000000000n);
            const elapsed = await vesting.connect(owner).timeElapsed();
            console.log("Time elapsed", elapsed)
            const cliff = await vesting.connect(owner).cliff();
            console.log("Cliff:", cliff);
            // Now available() should equal allocated()
            expect(await vesting.connect(owner).available()).to.equal(allocated);
        });
    });
});
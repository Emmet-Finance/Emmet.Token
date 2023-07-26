import {
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import exp from "constants";
import { ethers } from "hardhat";
import { EmmetVesting__factory } from "../typechain-types";

// async function sleep(ms: number) {
//     return await new Promise( resolve => setTimeout(resolve, ms) );
// }

describe("Emet.Vesting", function () {

    const addressZero: string = "0x0000000000000000000000000000000000000000";
    const invest250M: bigint = 250000000000000000000000000n;

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

    describe("Start Emet.Vesting Testing", function () {

        it("Should Deploy", async function () {
            const { token, vesting } = await loadFixture(deployContracts);
            // The address of `Token` must equal token.getAddress()
            expect(await vesting.Token()).to.equal(await token.getAddress());
            // halfYear muts equal 15811200 seconds
            expect(await vesting.halfYear()).to.equal(15811200n);
        });

        it("Should NOT Deploy", async function () {
            // Extract hardhat accounts
            const [owner, otherAccount] = await ethers.getSigners();
            const { token, vesting } = await loadFixture(deployContracts);
            // 1. Fail to deploy a vesting contract instance with addressZero as Token.address
            const EmmetVesting = await ethers.getContractFactory("EmmetVesting");
            await expect(EmmetVesting.deploy(addressZero, otherAccount))
                .to.be.revertedWithCustomError(vesting, "AddressError")
                .withArgs(addressZero, "Wrong token address");
            // 2. Fail to deploy a vesting contract instance with addressZero as CFO
            await expect(EmmetVesting.deploy(await token.getAddress(), addressZero))
                .to.be.revertedWithCustomError(vesting, "AddressError")
                .withArgs(addressZero, "Is not a valid CFO address.");
            // 3. Fail to deploy, the Token address is not a contract
            await expect(EmmetVesting.deploy(owner.address, otherAccount))
                .to.be.revertedWithCustomError(vesting, "AddressError")
                .withArgs(owner.address, "Token address is not a contract");
        });

        it("Should NOT add Beneficiary - No Allowance", async function () {
            const { vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // Add owner as beneficiary
            await expect(vesting.connect(otherAccount).addBeneficiary(owner.address, invest250M, 1n, 1n))
                .to.be.revertedWithCustomError(vesting, "AmountError")
                .withArgs(invest250M, "Available Token allowance", 0);
        });

        it("Should add Beneficiary", async function () {
            const { token, vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // The otherAccount should have a balance of 1 bn
            expect(await token.balanceOf(otherAccount)).to.equal(1000000000n * 10n ** 18n);
            // Approve in the token contract
            await token.connect(otherAccount).approve(await vesting.getAddress(), invest250M);
            // Add owner as beneficiary
            await vesting.connect(otherAccount).addBeneficiary(owner.address, invest250M, 1n, 1n);
            // Check the beneficiary was added & 250M allocated
            expect((await vesting.connect(owner).getBeneficiary(owner.address)).allocated)
                .to.equal(invest250M);
            // Check allocated()
            expect(await vesting.connect(owner).allocated()).to.equal(invest250M);
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
            expect(await vesting.connect(owner).unwithdrawn()).to.equal(invest250M);
            // Check withdrawn()
            expect(await vesting.connect(owner).withdrawn()).to.equal(0n);
        });

        it("Admin should update CFO, Token, Admin", async function () {
            const { token, vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // Update admin
            await vesting.connect(owner).updateAdmin(otherAccount.address);
            // The new admin shoud update CFO
            await vesting.connect(otherAccount).updateCFO(owner.address);
            // Update Token address
            await vesting.connect(otherAccount).updateTokenContract(await token.getAddress());
            // Transfer tokens to the `owner` account
            await token.connect(otherAccount).transfer(owner.address, invest250M);
            // Approve
            await token.connect(owner).approve(await vesting.getAddress(), invest250M);
            // The new CFO should add a beneficiary
            await vesting.connect(owner).addBeneficiary(otherAccount.address, invest250M, 1n, 1n);
            // The beneficiary should see their allocation
            expect(await vesting.connect(otherAccount).allocated()).to.equal(invest250M);
        });

        it("Admin updates Beneficiary, Beneficiary withdraws", async function () {
            const { token, vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // The otherAccount should have a balance of 1 bn
            expect(await token.balanceOf(otherAccount)).to.equal(1000000000n * 10n ** 18n);
            // Approve in the token contract
            await token.connect(otherAccount).approve(await vesting.getAddress(), 250000000n * 10n ** 18n);
            // Add owner as beneficiary
            await vesting.connect(otherAccount).addBeneficiary(owner.address, 250000000n * 10n ** 18n, 1n, 1n);
            // Check beneficiary has allocation
            expect(await vesting.connect(owner).allocated()).to.equal(invest250M);
            // Admin updates the Beneficiary
            await vesting.connect(owner).updateBeneficiary(owner.address, {
                allocated: invest250M,
                withdrawn: 0n,
                start: 0n, // This was changed to enable withdraw
                cliff: 0n, // This was changed to enable withdraw
                vesting: 0n // This was changed to enable 100% withdraw
            });
            const beneficiary = await vesting.connect(owner).getBeneficiary(owner.address);
            expect(beneficiary).to.deep.equal([invest250M, 0n, 0n, 0n, 0n]);
            // Now available() should equal allocated()
            const allocated = await vesting.connect(owner).allocated();
            expect(allocated).to.equal(invest250M);
            expect(await vesting.connect(owner).unwithdrawn()).to.equal(allocated);
            const elapsed = await vesting.connect(owner).timeElapsed();
            console.log("Elapsed", elapsed)
            const cliff = await vesting.connect(owner).cliff();
            console.log("Cliff:", cliff);
            const vest = await vesting.connect(owner).getVesting();
            console.log("Vesting", vest)
            console.log("vest <= (elapsed - cliff)", vest <= (elapsed - cliff));
            const unwithdrawn = await vesting.connect(owner).unwithdrawn();
            console.log("Unwithdrawn:", unwithdrawn)
            expect(unwithdrawn).to.equal(allocated)
            expect(await vesting.connect(owner).available()).to.equal(allocated);
            await vesting.withdraw(allocated);
            expect(await vesting.unwithdrawn()).to.equal(0n);
        });

        it("Should withdraw 50% during vesting", async function () {
            const { token, vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // The otherAccount should have a balance of 1 bn
            expect(await token.balanceOf(otherAccount)).to.equal(1000000000n * 10n ** 18n);
            // Cannot withdraw - the contract has no/not enough tokens 
            await expect(vesting.connect(owner).withdraw(invest250M / 2n))
                .to.be.revertedWithCustomError(vesting, "AmountError")
                .withArgs(invest250M / 2n, "The contract only has", 0n);
            // Approve in the token contract
            await token.connect(otherAccount).approve(await vesting.getAddress(), invest250M);
            // Add owner as beneficiary [250M, no cliff, twoYears vesting]
            await vesting.connect(otherAccount).addBeneficiary(owner.address, invest250M, 0n, 1n);
            // Check beneficiary has allocation
            expect(await vesting.connect(owner).allocated()).to.equal(invest250M);
            // Get the beneficiary data
            let beneficiary = await vesting.connect(owner).getBeneficiary(owner.address);
            // Admin updates the Beneficiary
            await vesting.connect(owner).updateBeneficiary(owner.address, {
                allocated: beneficiary.allocated,
                withdrawn: beneficiary.withdrawn,
                start: beneficiary.start - 31622400n, // Pretend one year passed to enable 50% withdraw
                cliff: beneficiary.cliff, // This remained to enable withdraw during vesting
                vesting: beneficiary.vesting // This remained to enable partial 50% withdraw during vesting
            });
            // Now 250M / 2 must be available for withdrawal
            const half = await vesting.connect(owner).available();
            expect(half).to.equal(invest250M / 2n);
            await vesting.connect(owner).withdraw(half);
            expect(await vesting.connect(owner).unwithdrawn()).to.equal(half);
            expect(await vesting.connect(owner).available()).to.equal(0n);
            expect(await token.balanceOf(owner.address)).to.equal(half);
            // Cannot withdraw again now till the vesting matures
            await expect(vesting.connect(owner).withdraw(invest250M / 2n))
                .to.be.revertedWithCustomError(vesting, "AmountError")
                .withArgs(invest250M / 2n, "Available now", 0n);
        });

        it("CFO Should NOT add beneficiary", async function () {
            const { token, vesting, owner, otherAccount } = await loadFixture(deployContracts);
            // The otherAccount should have a balance of 1 bn
            expect(await token.balanceOf(otherAccount)).to.equal(1000000000n * 10n ** 18n);
            // Approve in the token contract
            await token.connect(otherAccount).approve(await vesting.getAddress(), invest250M);
            // Cannot add address addressZero
            await expect(vesting.connect(otherAccount)
                .addBeneficiary(addressZero, invest250M, 0n, 1n))
                .to.be.revertedWithCustomError(vesting, "AddressError")
                .withArgs(addressZero, "Cannot assign to address zero");
            // Cannot add with zero amount
            await expect(vesting.connect(otherAccount).addBeneficiary(owner.address, 0n, 0n, 1n))
                .to.be.revertedWithCustomError(vesting, "AmountError")
                .withArgs(0n, "Cannot add a msg.sender with amount", 0n);
            // Now add normally to lay the scene for the next revert
            await vesting.connect(otherAccount).addBeneficiary(owner.address, invest250M, 0n, 1n);
            // Check that addition worked
            expect(await vesting.connect(owner).allocated()).to.equal(invest250M);
            // Cannot add a beneficiary again
            await expect(vesting.connect(otherAccount).addBeneficiary(owner.address, invest250M, 0n, 1n))
                .to.be.revertedWithCustomError(vesting, "AddressError")
                .withArgs(owner.address, "Beneficiary already added");
        });
    });
});
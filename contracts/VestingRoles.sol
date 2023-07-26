// SPDX-License-Identifier: MIT
pragma solidity >0.6.0 <0.8.20;

import "./TokenVesting.sol";

contract VestingRoles is TokenVesting {

    address internal admin;      // Contract admin
    address internal CFO;        // Chief Financial Officer

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorised call");
        _;
    }

    modifier onlyCFO() {
        require(msg.sender == CFO, "Unauthorised call");
        _;
    }

    constructor(address token_, address CFO_) TokenVesting(token_) {
        if(CFO_ == address(0)){
            revert AddressError(CFO_, "Is not a valid CFO address.");
        }
        admin = msg.sender;
        CFO = CFO_;
    }

    /**************************************************************************
     *                              O N L Y    C F O                          *
     **************************************************************************/
    function addBeneficiary(
        address receiver_, // Should not be address(0)
        uint128 amount_, // Should be > uint128(0)
        Cliffs cliff_, // {0: Immediately, 1: halfYear, 2: OneYear}
        Vesting vesting_ // {0: Immediately, 1: TwoYears, 2: FourYears}
    ) external onlyCFO {
        // Input check 1:
        if (receiver_ == address(0)) {
            revert AddressError(receiver_, "Cannot assign to address zero");
        }
        // Input check 2:
        if (amount_ == uint128(0)) {
            revert AmountError(
                amount_,
                "Cannot add a msg.sender with amount",
                uint128(0)
            );
        }
        // Beneficiary can only be set once not to corrupt the vesting schedule!
        if (beneficiaries[receiver_].allocated > 0) {
            revert AddressError(receiver_, "Beneficiary already added");
        }
        // Check whether allowance is enough
        uint256 allowance_ = Token.allowance(msg.sender, address(this));
        if (allowance_ < amount_) {
            revert AmountError(
                amount_,
                "Available Token allowance",
                uint128(allowance_)
            );
        }
        // Transfer enough tokens to the vesting contract
        SafeERC20.safeTransferFrom(
            Token,
            msg.sender,
            address(this),
            amount_
        );

        // Set a new msg.sender
        beneficiaries[receiver_] = Beneficiary({
            allocated: amount_,
            withdrawn: uint128(0),
            start: block.timestamp,
            cliff: cliff_,
            vesting: vesting_
        });
    }

    /**************************************************************************
     *                          O N L Y    A D M I N                          *
     **************************************************************************/
    function updateBeneficiary(
        address beneficiary,
        Beneficiary memory newBeneficiary
    ) external onlyAdmin {
        beneficiaries[beneficiary] = newBeneficiary;
    }

    function updateCFO(address newCFO) external onlyAdmin {
        CFO = newCFO;
    }

    function updateTokenContract(address newTokenContract) external onlyAdmin {
        Token = IERC20(newTokenContract);
    }

    function updateAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    function getBeneficiary(
        address beneficiary
    ) external view onlyAdmin returns (Beneficiary memory) {
        return beneficiaries[beneficiary];
    }

}
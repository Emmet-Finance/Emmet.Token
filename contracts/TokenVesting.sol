// SPDX-License-Identifier: MIT
pragma solidity >0.6.0 <0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenVesting {
    enum Cliffs {
        None, // 0
        HalfYear, // 1
        Year // 2
    }

    enum Vesting {
        None, // 0
        TwoYears, // 1
        FourYears // 2
    }

    struct Beneficiary {
        uint128 allocated; // Unit: base 18 Max ~3e38
        uint128 withdrawn; // Unit: base 18
        uint256 start; // block.timestamp
        Cliffs cliff; // {0: Immediately, 1: halfYear, 2: onefYear}
        Vesting vesting; // {0: Immediately, 1: TwoYears, 2: FourYears}
    }

    IERC20 public Token; // Token contract address

    uint64 public halfYear = 183 days; // 15811200 seconds
    uint64 public oneYear = halfYear * 2; // 31622400 seconds
    uint64 public twoYears = oneYear * 2; // 63244800 seconds

    mapping(address => Beneficiary) internal beneficiaries;

    error AddressError(address given, string message);
    error AmountError(uint128 required, string message, uint128 available);

    constructor(address token_) {
        if (token_ == address(0)) {
            revert AddressError(token_, "Wrong token address");
        }
        if (token_.code.length == 0) {
            revert AddressError(token_, "Token address is not a contract");
        }
        Token = IERC20(token_);
    }

    function _allocated() internal view returns (uint128) {
        return beneficiaries[msg.sender].allocated;
    }

    function _available() internal view returns (uint128) {
        // Time from start till now in past seconds
        uint256 elapsed = _timeElapsed();
        // The lock period when tokens cannot be released
        uint64 cliff_ = _cliff();
        // The period of linear token release
        uint64 vest_ = _getVesting();

        // Cliff has not matured, so nothing can be withdrawn
        if (cliff_ > uint64(elapsed)) {
            return uint128(0);
            // otherwise, two possible scenarios for cliff:
            // 1. cliff was initially 0
            // 2. cliff was > 0, but matured
            // Check whether vesting matured
        }

        // The time elapsed after cliff
        uint64 elapsedMinusCliff_;

        unchecked {
            // Underflow protection
            elapsedMinusCliff_ = uint64(elapsed) - cliff_;
            require(elapsedMinusCliff_ <= uint64(elapsed), "uint64 Underflow");
        }

        if (vest_ < uint64(elapsed) - cliff_) {
            // If matured, return allocation - withdrawn
            return _unwithdrawn();
        } else {
            // we're still in the vesting period
            // Calculate the vesting period
            uint64 inVesting_ = vest_ - elapsedMinusCliff_;
            // Calculate the proportion to total
            uint128 proportion = uint128(vest_ / inVesting_);
            return
                beneficiaries[msg.sender].allocated /
                proportion -
                beneficiaries[msg.sender].withdrawn;
        }
    }

    function _cliff() internal view returns (uint64) {
        // The period of token lock length in seconds
        return uint64(beneficiaries[msg.sender].cliff) * halfYear;
    }

    function _getVesting() internal view returns (uint64) {
        // The period of linear token release length in seconds
        return uint64(beneficiaries[msg.sender].vesting) * twoYears;
    }

    function _timeElapsed() internal view returns (uint256) {
        // Time from start till now in seconds
        return block.timestamp - beneficiaries[msg.sender].start;
    }

    function _unwithdrawn() internal view returns (uint128) {
        // Full amount left to withdraw regardless of locks & schedules
        return beneficiaries[msg.sender].allocated - _withdrawn();
    }

    function _withdraw(uint128 amount_) internal {
        // The contract must have enough funds
        if (Token.balanceOf(address(this)) < amount_) {
            revert AmountError(
                amount_,
                "The contract only has",
                uint128(Token.balanceOf(address(this)))
            );
        }

        // The msg.sender must have enough available tokens
        uint128 available_ = _available();
        // Or the requested amount must be <= available
        if (available_ == uint128(0) || amount_ > available_) {
            revert AmountError(amount_, "Available now", available_);
        }

        // Transfer the requested amount
        bool result = Token.transfer(msg.sender, amount_);
        require(result == true, "Vested token transfer failed.");

        // Update withdrawal amount
        beneficiaries[msg.sender].withdrawn += amount_;
    }

    function _withdrawn() internal view returns (uint128) {
        // Amount of received tokens with 18 decimals
        return beneficiaries[msg.sender].withdrawn;
    }
}

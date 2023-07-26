// SPDX-License-Identifier: MIT
pragma solidity >0.6.0 <0.8.20;

import "./VestingRoles.sol";

contract EmmetVesting is VestingRoles {

    constructor(address token_, address CFO_) VestingRoles(token_, CFO_) {}

    /**************************************************************************
     *                    O N L Y    B E N E F I C I A R Y                    *
     **************************************************************************/

    function allocated() external view returns (uint128) {
        return _allocated();
    }

    function available() external view returns (uint128) {
        // Amount of tokens withdrawable at the moment
        // Taking into account cliff & vesting maturity
        return _available();
    }

    function cliff() external view returns (uint64) {
        // The period of token lock length in seconds
        return _cliff();
    }

    function getVesting() external view returns (uint64) {
        // The period of linear token release length in seconds
        return _getVesting();
    }

    function timeElapsed() external view returns (uint256) {
        // Time from start till now in seconds
        return _timeElapsed();
    }

    function unwithdrawn() external view returns (uint128) {
        // Full amount left to withdraw regardless of locks & schedules
        return _unwithdrawn();
    }

    function withdrawn() external view returns (uint128) {
        // Amount of received tokens with 18 decimals
        return _withdrawn();
    }

    function withdraw(uint128 amount_) external {
        // The msg.sender withdraws available amount
        _withdraw(amount_);
    }
}

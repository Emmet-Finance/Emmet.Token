// SPDX-License-Identifier: MIT
pragma solidity >0.6.0 <0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EmmetVesting {
    enum Cliffs {
        None, // 0
        HalfYear, // 1
        Year // 2
    }

    enum Vesting {
        TwoYears, // 0
        FourYears // 1
    }

    struct Beneficiary {
        uint128 allocated; // Unit: base 18 Max ~3e38
        uint128 withdrawn; // Unit: base 18
        uint256 start; // block.timestamp
        Cliffs cliff; // {0, halfYear, 2*halfYear}
        Vesting vesting; // {0: TwoYears, 1: FourYears}
    }

    address private admin;
    IERC20 public emmetToken;
    uint64 public halfYear = 183 days;
    uint64 public oneYear = halfYear * 2;
    uint64 public twoYears = oneYear * 2;
    uint64 public fourYears = twoYears * 2;

    mapping(address => Beneficiary) private beneficiaries;

    error AddressError(address given, string message);
    error AmountError(uint128 required, string message, uint128 available);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorised call");
        _;
    }

    modifier onlyEligible() {
        require(beneficiaries[msg.sender].allocated > 0, "Unauthorised call.");
        _;
    }

    constructor(address _token) {
        if (_token == address(0)) {
            revert AddressError(_token, "Wrong token address");
        }
        // if(_token.code.length == 0){
        //     revert AddressError(_token, "Token address is not a contract");
        // }
        emmetToken = IERC20(_token);
        admin = msg.sender;
    }

    function addBeneficiary(
        address receiver,
        uint128 _amount,
        Cliffs _cliff, // {0,1,2}
        Vesting _vesting // {0,1}
    ) external onlyAdmin {
        // Cannot assign to address zero
        if (receiver == address(0)) {
            revert AddressError(receiver, "Wrong token address");
        }
        // Address can only be used once!
        if (beneficiaries[receiver].allocated > 0) {
            revert AddressError(receiver, "Beneficiary already added");
        }

        beneficiaries[receiver] = Beneficiary({
            allocated: _amount,
            withdrawn: uint128(0),
            start: block.timestamp,
            cliff: _cliff,
            vesting: _vesting
        });
    }

    function getBeneficiary(address beneficiary)
        external view
        returns (Beneficiary memory)
    {
        return beneficiaries[beneficiary];
    }

    function timeElapsed(address beneficiary) external view returns (uint256) {
        return block.timestamp - beneficiaries[beneficiary].start;
    }

    function unwithdrawn(address beneficiary) external view returns (uint128) {
        return
            beneficiaries[beneficiary].allocated -
            beneficiaries[beneficiary].withdrawn;
    }

    function available(address beneficiary) external returns (uint128) {
        Beneficiary storage _beneficiary = beneficiaries[beneficiary];
        uint256 elapsed = block.timestamp - _beneficiary.start;
        uint128 remainingTokens = _beneficiary.allocated -
            _beneficiary.withdrawn;

        // Check the cliff
        uint64 _cliff = uint64(_beneficiary.cliff) * halfYear;

        if (_cliff > 0 && elapsed <= _cliff) {
            return uint128(0);
        }

        // Check the vesting
        uint64 _vest;

        if (_beneficiary.vesting == Vesting.TwoYears) {
            _vest = twoYears;
        }

        if (_beneficiary.vesting == Vesting.FourYears) {
            _vest = fourYears;
        }
    }

    function withdraw(uint128 _amount) external onlyEligible {
        // The contract must have enough funds
        if (emmetToken.balanceOf(address(this)) < _amount) {
            revert AmountError(
                _amount,
                "The contract has:",
                uint128(emmetToken.balanceOf(address(this)))
            );
        }

        Beneficiary storage _beneficiary = beneficiaries[msg.sender];

        // The beneficiary must have enough available tokens
    }
}

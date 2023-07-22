// SPDX-License-Identifier: MIT
pragma solidity >0.6.0 <0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EmmetVesting {
    enum Cliffs {
        None,                   // 0
        HalfYear,               // 1
        Year                    // 2
    }

    enum Vesting {
        None,                   // 0
        TwoYears,               // 1
        FourYears               // 2
    }

    struct Beneficiary {
        uint128 allocated;      // Unit: base 18 Max ~3e38
        uint128 withdrawn;      // Unit: base 18
        uint256 start;          // block.timestamp
        Cliffs  cliff;          // {0: Immediately, 1: halfYear, 2: 2*halfYear}
        Vesting vesting;        // {0: Immediately, 1: TwoYears, 2: FourYears}
    }

    address private admin;      // Contract admin
    address private CFO;        // Chief Financial Officer
    IERC20  public emmetToken;  // Address of the token contract

    uint64 public halfYear = 183 days;      // 15,811,200 seconds
    uint64 public oneYear = halfYear * 2;   // 31,622,400 seconds
    uint64 public twoYears = oneYear * 2;   // 63,244,800 seconds

    mapping(address => Beneficiary) private beneficiaries;

    error AddressError(address given, string message);
    error AmountError(uint128 required, string message, uint128 available);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorised call");
        _;
    }

    modifier onlyCFO() {
        require(msg.sender == CFO, "Unauthorised call");
        _;
    }

    modifier onlyEligible() {
        require(beneficiaries[msg.sender].allocated > 0, "Unauthorised call.");
        _;
    }

    constructor(address _token, address _CFO) {
        if (_token == address(0)) {
            revert AddressError(_token, "Wrong token address");
        }
        if(_token.code.length == 0){
            revert AddressError(_token, "Token address is not a contract");
        }
        emmetToken = IERC20(_token);
        admin = msg.sender;
        CFO = _CFO;
    }

    /**************************************************************************
     *                    O N L Y    B E N E F I C I A R Y                    *
     **************************************************************************/

    function allocated(address beneficiary)
        external
        view
        onlyEligible
        returns (uint128)
    {
        return beneficiaries[beneficiary].allocated;
    }

    function available(address beneficiary)
        external
        view
        onlyEligible
        returns (uint128)
    {
        uint256 elapsed = this.timeElapsed(beneficiary);
        uint64 _cliff = this.cliff(beneficiary);

        // Cliff has not matured, so nothing can be withdrawn
        if (elapsed <= _cliff) {
            return uint128(0);
        } // else, two possible scenarios:
        // 1. cliff was initially 0
        // 2. cliff was > 0, but matured

        // Checkng the vesting period
        uint64 _vest = this.getVesting(beneficiary);
        // If vesting matured
        if (_vest <= (elapsed - _cliff)) {
            return this.unwithdrawn(beneficiary);
        } // else, we're still in the vesting period

        // Calculate the vesting period
        uint64 _inVesting = _vest - uint64(elapsed) - _cliff;
        // Calculate the proportion to total
        uint128 proportion = _vest / _inVesting;
        return
            this.allocated(beneficiary) /
            proportion -
            this.withdrawn(beneficiary);
    }

    function cliff(address beneficiary)
        external
        view
        onlyEligible
        returns (uint64)
    {
        return uint64(beneficiaries[beneficiary].cliff) * halfYear;
    }

    function getVesting(address beneficiary)
        external
        view
        onlyEligible
        returns (uint64)
    {
        return uint64(beneficiaries[beneficiary].vesting) * twoYears;
    }

    function timeElapsed(address beneficiary)
        external
        view
        onlyEligible
        returns (uint256)
    {
        return block.timestamp - beneficiaries[beneficiary].start;
    }

    function unwithdrawn(address beneficiary)
        external
        view
        onlyEligible
        returns (uint128)
    {
        return
            beneficiaries[beneficiary].allocated - this.withdrawn(beneficiary);
    }

    function withdrawn(address beneficiary)
        external
        view
        onlyEligible
        returns (uint128)
    {
        return beneficiaries[beneficiary].withdrawn;
    }

    function withdraw(uint128 _amount) external onlyEligible {
        // The contract must have enough funds
        if (emmetToken.balanceOf(address(this)) < _amount) {
            revert AmountError(
                _amount,
                "The contract only has",
                uint128(emmetToken.balanceOf(address(this)))
            );
        }

        // The beneficiary must have enough available tokens
        uint128 _available = this.available(msg.sender);
        // Or the requested amount must be <= available
        if (_available == uint128(0) || _amount > _available) {
            revert AmountError(_amount, "Available now", _available);
        }

        // Transfer the requested amount
        SafeERC20.safeTransfer(emmetToken, msg.sender, _amount);

        // Update withdrawal amount
        beneficiaries[msg.sender].withdrawn += _amount;
    }

    /**************************************************************************
     *                             O N L Y    C F O                           *
     **************************************************************************/
    function addBeneficiary(
        address receiver,   // Should not be address(0)
        uint128 _amount,    // Should be > uint128(0)
        Cliffs _cliff,      // {0: Immediately, 1: halfYear, 2: OneYear}
        Vesting _vesting    // {0: Immediately, 1: TwoYears, 2: FourYears}
    ) external onlyCFO {
        // Input check 1:
        if (receiver == address(0)) {
            revert AddressError(receiver, "Cannot assign to address zero");
        }
        // Input check 2:
        if (_amount == uint128(0)) {
            revert AmountError(
                _amount,
                "Cannot add a beneficiary with amount",
                uint128(0)
            );
        }
        // Beneficiary can only be set once not to corrupt the vesting schedule!
        if (beneficiaries[receiver].allocated > 0) {
            revert AddressError(receiver, "Beneficiary already added");
        }
        // Check whether allowance is enough
        uint256 allowance = emmetToken.allowance(msg.sender, address(this));
        if (allowance < _amount) {
            revert AmountError(
                _amount,
                "Available Token allowance",
                uint128(allowance)
            );
        }
        // Transfer enough tokens to the vesting contract
        SafeERC20.safeTransfer(emmetToken, address(this), _amount);

        // Set a new beneficiary
        beneficiaries[receiver] = Beneficiary({
            allocated: _amount,
            withdrawn: uint128(0),
            start: block.timestamp,
            cliff: _cliff,
            vesting: _vesting
        });
    }

    /**************************************************************************
     *                           O N L Y    A D M I N                         *
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
        emmetToken = IERC20(newTokenContract);
    }

    function updateAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    function getBeneficiary(address beneficiary)
        external
        view
        onlyAdmin
        returns (Beneficiary memory)
    {
        return beneficiaries[beneficiary];
    }
}

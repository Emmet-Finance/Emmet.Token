// SPDX-License-Identifier: MIT
pragma solidity >0.6.0 <0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract EmmetVesting {
    enum Cliffs {
        None,               // 0
        HalfYear,           // 1
        Year                // 2
    }

    enum Vesting {
        None,               // 0
        TwoYears,           // 1
        FourYears           // 2
    }

    struct Beneficiary {
        uint128 allocated;  // Unit: base 18 Max ~3e38
        uint128 withdrawn;  // Unit: base 18
        uint256 start;      // block.timestamp
        Cliffs cliff;       // {0: Immediately, 1: halfYear, 2: onefYear}
        Vesting vesting;    // {0: Immediately, 1: TwoYears, 2: FourYears}
    }

    address private admin;      // Contract admin
    address private CFO;        // Chief Financial Officer
    IERC20 public emmetToken;   // Token contract address

    uint64 public halfYear = 183 days;      // 15811200 seconds
    uint64 public oneYear = halfYear * 2;   // 31622400 seconds
    uint64 public twoYears = oneYear * 2;   // 63244800 seconds

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

    function allocated() external view returns (uint128) {
        return beneficiaries[msg.sender].allocated;
    }

    // TODO: fix this function - not working properly
    function available() external view returns (uint128) {
        uint256 elapsed = this.timeElapsed();
        uint64 _cliff = this.cliff();

        // Cliff has not matured, so nothing can be withdrawn
        if (uint256(_cliff) > elapsed) {
            return uint128(0); // Never gets here even if condition is true ?!
        } // else, two possible scenarios:
        // 1. cliff was initially 0
        // 2. cliff was > 0, but matured

        // Checkng the vesting period
        uint64 _vest = this.getVesting();
        // If vesting matured
        if (_vest <= (elapsed - _cliff)) {
            return this.unwithdrawn();
        } // else, we're still in the vesting period

        // Calculate the vesting period
        uint64 _inVesting = _vest - uint64(elapsed) - _cliff;
        // Calculate the proportion to total
        uint128 proportion = _vest / _inVesting;
        return this.allocated() / proportion - this.withdrawn();
    }

    function cliff() external view returns (uint64) {
        return uint64(beneficiaries[msg.sender].cliff) * halfYear;
    }

    function getVesting() external view returns (uint64) {
        return uint64(beneficiaries[msg.sender].vesting) * twoYears;
    }

    function timeElapsed() external view returns (uint256) {
        return block.timestamp - beneficiaries[msg.sender].start;
    }

    function unwithdrawn() external view returns (uint128) {
        return beneficiaries[msg.sender].allocated - this.withdrawn();
    }

    function withdrawn() external view returns (uint128) {
        return beneficiaries[msg.sender].withdrawn;
    }

    function withdraw(uint128 _amount) external {
        // The contract must have enough funds
        if (emmetToken.balanceOf(address(this)) < _amount) {
            revert AmountError(
                _amount,
                "The contract only has",
                uint128(emmetToken.balanceOf(address(this)))
            );
        }

        // The msg.sender must have enough available tokens
        uint128 _available = this.available();
        // Or the requested amount must be <= available
        if (_available == uint128(0) || _amount > _available) {
            revert AmountError(_amount, "Available now", _available);
        }

        // Transfer the requested amount
        SafeERC20.safeTransferFrom(emmetToken, address(this), msg.sender, _amount);

        // Update withdrawal amount
        beneficiaries[msg.sender].withdrawn += _amount;
    }

    /**************************************************************************
     *                              O N L Y    C F O                          *
     **************************************************************************/
    function addBeneficiary(
        address receiver, // Should not be address(0)
        uint128 _amount, // Should be > uint128(0)
        Cliffs _cliff, // {0: Immediately, 1: halfYear, 2: OneYear}
        Vesting _vesting // {0: Immediately, 1: TwoYears, 2: FourYears}
    ) external onlyCFO {
        // Input check 1:
        if (receiver == address(0)) {
            revert AddressError(receiver, "Cannot assign to address zero");
        }
        // Input check 2:
        if (_amount == uint128(0)) {
            revert AmountError(
                _amount,
                "Cannot add a msg.sender with amount",
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
        SafeERC20.safeTransferFrom(emmetToken, msg.sender, address(this), _amount);

        // Set a new msg.sender
        beneficiaries[receiver] = Beneficiary({
            allocated: _amount,
            withdrawn: uint128(0),
            start: block.timestamp,
            cliff: _cliff,
            vesting: _vesting
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

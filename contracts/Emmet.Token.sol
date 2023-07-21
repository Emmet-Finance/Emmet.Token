// // SPDX-License-Identifier: UNLICENSED
// pragma solidity >0.6.0 <0.8.20;

// // Owner or Spender can burn tokens under their control
// import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// contract EmmetToken is ERC20Burnable{

//     constructor(
//         address vault,
//         address treasury
//     ) ERC20 ("EMMET", "EMMET"){
//         // 250 M Investments
//         _mint(vault, 250_000_000 ether);
//         // 750 M Community
//         _mint(treasury, 750_000_000 ether);
//     }

// }
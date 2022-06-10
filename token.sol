// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

// Import OpenZeppelin Libraries
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract RastacoinToken is ERC20, ERC20Burnable {
    constructor() ERC20("RastaCoin", "RCOIN") {
        // Generate Maximum Total Supply of RastaCoin
        _mint(msg.sender, 40000000 * 10 ** 18);
    }
}

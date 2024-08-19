// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {DeployEx} from "../../script/DeployEx.s.sol";
import {UpgradeEx} from "../../script/UpgradeEx.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ExAsset} from "../../src/ExAsset.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

/**
 * 包含了主要方法的测试用例；
 * 预言机相关测试 包含在 swap  withdraw 内部
 */
contract ExAssetTest is StdCheats, Test {
    event AssetDeposited(address indexed user, uint256 indexed amount);
    event AssetSwap(address indexed user, uint256 indexed eth_amount, uint256 indexed u_amount);
    event AssetOwnerWithdraw(address indexed owner, uint256 indexed eth_amount, uint256 indexed u_amount);

    DeployEx public deployEx;
    UpgradeEx public upgradeEx;
    ExAsset public exAsset;
    HelperConfig public helperConfig;
    address public priceFeed;
    address public usdc;
    uint256 public deployerKey;

    address public user = address(1);
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() public {
        deployEx = new DeployEx();
        upgradeEx = new UpgradeEx();
        (exAsset, helperConfig) = deployEx.deployEx();
        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }

        (priceFeed, usdc, deployerKey) = helperConfig.activeNetworkConfig();
        ERC20Mock(usdc).mint(address(exAsset), 500 ether);
    }

    /**
     * initializer
     */
    function testInializer_onlyOnce() public {
        vm.expectRevert();
        vm.startPrank(user);
        exAsset.initialize(priceFeed, usdc);
        vm.stopPrank();
    }

    /**
     * deposit
     */
    function testDeposit_moreThanZero() public {
        vm.expectRevert(ExAsset.ExAsset__NeedsMoreThanZero.selector);
        vm.startPrank(user);
        exAsset.deposit();
        // right way:  exAsset.deposit{value: 100}();
        vm.stopPrank();
    }

    function testDeposit_success() public {
        uint256 old_balance = exAsset.balances(user);
        uint256 old_balanceOfUser = exAsset.balanceOfUser();
        // bytes32 val = vm.load(address(exAsset), bytes32(uint256(2)));
        // uint256 balanceOfUser = uint256(val);

        vm.expectEmit(true, true, false, false, address(exAsset));
        emit AssetDeposited(user, 1000);
        vm.startPrank(user);
        exAsset.deposit{value: 1000}();
        vm.stopPrank();

        assertEq(exAsset.balances(user), old_balance + 1000);
        assertEq(exAsset.balanceOfUser(), old_balanceOfUser + 1000);
    }

    modifier depositSomeETH() {
        vm.startPrank(user);
        exAsset.deposit{value: 1 ether}();
        vm.stopPrank();
        _;
    }

    /**
     * swap
     */
    function testSwap_balanceNotEnough() public {
        vm.expectRevert(ExAsset.ExAsset__BalanceNotEnough.selector);
        vm.startPrank(user);
        exAsset.swap(0);
        vm.stopPrank();
    }

    function testSwap_success() public depositSomeETH {
        uint256 old_balance = exAsset.balances(user);
        uint256 old_balanceOfUser = exAsset.balanceOfUser();

        vm.expectEmit(true, true, true, false, address(exAsset));
        emit AssetSwap(user, 1000, 2000000);
        vm.startPrank(user);
        exAsset.swap(1000);
        vm.stopPrank();

        assertEq(exAsset.balances(user), old_balance - 1000);
        assertEq(exAsset.balanceOfUser(), old_balanceOfUser - 1000);
    }

    modifier depositAndSwap() {
        vm.startPrank(user);
        exAsset.deposit{value: 1 ether}();
        exAsset.swap(0.1 ether);
        vm.stopPrank();
        _;
    }

    /**
     * withdraw
     */
    function testWithdraw_notOwner() public {
        vm.expectRevert();
        // vm.startPrank(user);
        exAsset.withdraw();
        vm.stopPrank();
    }

    function testWithdraw_success_simple() public depositAndSwap {
        address deployUser = vm.addr(deployerKey);

        vm.startPrank(deployUser);
        exAsset.withdraw();
        vm.stopPrank();
    }

    function testWithdraw_success_oracle() public depositAndSwap {
        // console.log(address(exAsset.owner()));
        // console.log(vm.addr(deployerKey));

        address deployUser = vm.addr(deployerKey);

        vm.expectEmit(true, true, true, false, address(exAsset));
        emit AssetOwnerWithdraw(deployUser, 0.1 ether, 500 ether - 0.1 ether * 2000);
        vm.startPrank(deployUser);
        exAsset.withdraw();
        vm.stopPrank();

        assertEq(deployUser.balance, 0.1 ether);
        assertEq(ERC20Mock(usdc).balanceOf(deployUser), 500 ether - 0.1 ether * 2000);
    }

    /**
     * upgrade
     */
    function testUpgrade() public depositAndSwap {
        address newProxy = upgradeEx.upgradeEx(address(exAsset));
        ExAsset newExAsset = ExAsset(newProxy);
        assertEq(newExAsset.balances(user), 0.9 ether);
        assertEq(newExAsset.balanceOfUser(), 0.9 ether);
    }
}

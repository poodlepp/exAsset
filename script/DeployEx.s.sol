// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {ExAsset} from "../src/ExAsset.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployEx is Script {
    function run() external {
        deployEx();
    }

    function deployEx() public returns (ExAsset, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address priceFeed, address usdc, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        ExAsset exAsset = new ExAsset();
        ERC1967Proxy proxy = new ERC1967Proxy(address(exAsset), "");
        ExAsset(address(proxy)).initialize(priceFeed, usdc);
        vm.stopBroadcast();
        return (ExAsset(address(proxy)), helperConfig);
    }
}

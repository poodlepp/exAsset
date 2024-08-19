// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {ExAsset} from "../src/ExAsset.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract UpgradeEx is Script {
    function run() external returns (address) {
        address currentProy = address(0x7774bBf74DAe45bC89796AD2906277e7BD8e6C6d);
        address proxy = upgradeEx(currentProy);
        return proxy;
    }

    function upgradeEx(address proxyAddress) public returns (address) {
        HelperConfig helperConfig = new HelperConfig();
        (,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        ExAsset newEx = new ExAsset();
        ExAsset proxy = ExAsset(payable(proxyAddress));
        proxy.upgradeTo(address(newEx));
        vm.stopBroadcast();
        return address(proxy);
    }
}

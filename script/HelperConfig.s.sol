// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;

    struct NetworkConfig {
        address priceFeed;
        address usdc;
        uint256 deployerKey;
    }

    uint256 private DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11_155_111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() internal view returns (NetworkConfig memory config) {
        config.priceFeed = address(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        config.usdc = address(0x254d06f33bDc5b8ee05b2ea472107E300226659A);
        config.deployerKey = vm.envUint("PRIVATE_KEY");
        return config;
    }

    function getOrCreateAnvilEthConfig() internal returns (NetworkConfig memory config) {
        if (activeNetworkConfig.priceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock usdcMock = new ERC20Mock();
        vm.stopBroadcast();

        config = NetworkConfig({
            priceFeed: address(ethUsdPriceFeed),
            usdc: address(usdcMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}

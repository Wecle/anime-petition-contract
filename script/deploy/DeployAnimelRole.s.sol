// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ConfigScript} from "../ConfigScript.s.sol";
import {ConfigTools} from "../ScriptTools.sol";
import {AnimeRole} from "../../src/nft/AnimeRole.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployAnimelRole is ConfigScript {
    address public animeRoleProxy;
    address public animeRoleImpl;
    uint256 public currentNftid;
    string[] public animeRoleUris;
    address public deployer;
    uint256 public deployerPrivateKey;

    function setUp() public override {
        super.setUp();

        // Initialize deployer
        deployerPrivateKey = vm.envUint("DEPLOY_KEY");
        deployer = vm.addr(deployerPrivateKey);

        // Initialize URIs
        animeRoleUris = new string[](3);
        animeRoleUris[0] = "https://gateway.pinata.cloud/ipfs/QmSnqJqZUfwEafVnn4ftzxgrFiED531segL36c9A9MdRL9";
        animeRoleUris[1] = "https://gateway.pinata.cloud/ipfs/QmWsUwVmeTgan7LwsRsHdvMqwycmEuhErnyAjQUk4j5Y7J";
        animeRoleUris[2] = "https://gateway.pinata.cloud/ipfs/QmbioTx6h7aCBwJMaF1sqcCPUrZBaeY96FWHKwc4sVBSHv";
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation contract
        AnimeRole implementation = new AnimeRole();
        animeRoleImpl = address(implementation);

        // Deploy proxy admin
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployer);

        // Initialize implementation
        bytes memory initData = abi.encodeCall(AnimeRole.initialize, (animeRoleUris, block.timestamp));

        // Deploy proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            animeRoleImpl,
            address(proxyAdmin),
            initData
        );
        animeRoleProxy = address(proxy);

        // Log deployment info
        console.log("Implementation deployed at:", animeRoleImpl);
        console.log("Proxy deployed at:", animeRoleProxy);
        console.log("Proxy Admin:", address(proxyAdmin));
        console.log("Deployer:", deployer);

        // Export contract addresses
        exportContracts();

        vm.stopBroadcast();
    }

    function exportContracts() internal {
        string memory configName = ConfigTools.getConfigName();
        ConfigTools.exportContract(configName, "deployer", deployer);
        ConfigTools.exportContract(configName, "animeRoleProxy", animeRoleProxy);
        ConfigTools.exportContract(configName, "animeRoleImpl", animeRoleImpl);
    }
}

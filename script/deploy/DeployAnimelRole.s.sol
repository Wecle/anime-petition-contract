// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ConfigScript} from "../ConfigScript.s.sol";
import {ConfigTools} from "../ScriptTools.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {AnimeRole} from "../../src/nft/AnimeRole.sol";

contract DeployScript is ConfigScript {
    using ConfigTools for string;
    using stdJson for string;

    uint256 deployerPrivateKey;
    address deployer;

    address owner;
    address proxyAdmin;

    address animeRoleProxy;
    address animeRoleImpl;
    string[] animeRoleUris;

    uint256 currentNftid;

    function setUp() public override {
        super.setUp();

        parseConfig();
        deployerPrivateKey = vm.envUint("DEPLOY_KEY");
        deployer = vm.addr(deployerPrivateKey);

        require(owner == deployer, "owner not match deployer");
    }

    function parseConfig() internal {
        owner = config.readAddress(".owner");
        proxyAdmin = config.readAddress(".proxyAdmin");
        
        // nft config
        animeRoleUris = new string[](3);
        animeRoleUris[0] = config.readString(".sasukeUrl");
        animeRoleUris[1] = config.readString(".narutoUrl");
        animeRoleUris[2] = config.readString(".sakuraUrl");
    }

    function run() public {
        console.log("owner: ", owner, ", deployer: ", deployer);
        console.log("proxyAdmin: ", proxyAdmin);

        console.log("=== 1/ nft config ===");
        console.log("sasukeUrl: ", animeRoleUris[0]);
        console.log("narutoUrl: ", animeRoleUris[1]);
        console.log("sakuraUrl: ", animeRoleUris[2]);

        console.log("\n");

        deployAnimeRole();

        console.log("\n");
        console.log("=== 2/ nft info ===");
        console.log(
            "animelRole name: ", AnimeRole(animeRoleProxy).name(), ", symbol: ", AnimeRole(animeRoleProxy).symbol()
        );
        currentNftid = AnimeRole(animeRoleProxy).nftId();
        console.log("already published nft id: ", currentNftid);
        for (uint256 i = 0; i < currentNftid; i++) {
            console.log("nft id: ", i, ", uri: ", AnimeRole(animeRoleProxy).uri(i));
            console.log("nft max: ", AnimeRole(animeRoleProxy).maxSupply(i));
        }

        exportContracts();
    }

    function deployAnimeRole() internal {
        vm.startBroadcast(deployerPrivateKey);
        // deploy anime role
        animeRoleProxy = Upgrades.deployTransparentProxy(
            "AnimeRole.sol",
            proxyAdmin,
            abi.encodeCall(
                AnimeRole.initialize, (animeRoleUris, block.timestamp)
            )
        );
        animeRoleImpl = Upgrades.getImplementationAddress(animeRoleProxy);

        vm.stopBroadcast();
    }

    
    function exportAnimeRole() internal {
        string memory configName = ConfigTools.getConfigName();
        ConfigTools.exportContract(configName, "animeRoleProxy", animeRoleProxy);
        ConfigTools.exportContract(configName, "animeRoleImpl", animeRoleImpl);
    }

    function exportContracts() internal {
        string memory configName = ConfigTools.getConfigName();
        ConfigTools.exportContract(configName, "deployer", deployer);
        ConfigTools.exportContract(configName, "owner", owner);
        ConfigTools.exportContract(configName, "proxyAdmin", proxyAdmin);

        exportAnimeRole();
    }
}

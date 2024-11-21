// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ConfigScript} from "../ConfigScript.s.sol";
import {ConfigTools} from "../ScriptTools.sol";
import {AnimeRole} from "../../src/nft/AnimeRole.sol";

contract RunAnimeRoleScript is ConfigScript {
    address animeRoleProxy;
    uint256 deployerPrivateKey;
    address deployer;

    function setUp() public override {
        animeRoleProxy = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
    }

    function getAnimeRoleData() public {
        console.log(
            "AnimeRole name: ",
            AnimeRole(animeRoleProxy).name(),
            "symbol: ",
            AnimeRole(animeRoleProxy).symbol()
        );
        console.log(
            "msg.sender: ",
            msg.sender
        );
    }

    function mitAnimeRole() public {
        vm.startPrank(msg.sender);
        AnimeRole(animeRoleProxy).mintAnimeRoleNft{value: 0.005 ether}(3, 5);
        console.log("sakura minted: ", AnimeRole(animeRoleProxy).balanceOf(msg.sender, 3));
        console.log("sakura userTotalMinted: ", AnimeRole(animeRoleProxy).userTotalMinted(msg.sender, 3));
        vm.stopPrank();
    }

    function run() public {
        getAnimeRoleData();
        mitAnimeRole();
    }
}
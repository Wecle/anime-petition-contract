// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ConfigTools} from "./ScriptTools.sol";

contract ConfigScript is Script {
    string public config;

    function setUp() public virtual {
        vm.setEnv(ConfigTools.CONFIG_ENV_ROOT_CHAINID, vm.toString(block.chainid));
        string memory chainInfo = vm.envString(ConfigTools.CONFIG_ENV_SCRIPT_CHAININFO);

        string memory configName = ConfigTools.getConfigName();
        config = ConfigTools.loadConfig(configName);

        console.log("\n########## ConfigScript.setUp() ##########");
        console.log(
            "\nConfigScript.setUp() configName: %s, chainInfo: %s, chainId: %s",
            configName,
            chainInfo,
            block.chainid
        );
        console.log("\n%s", config);
        console.log("\n########## ConfigScript.setUp() ##########\n");
    }
}

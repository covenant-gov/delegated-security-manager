// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from 'forge-std/Script.sol';
import {DSM} from 'src/contracts/DSM.sol';

uint256 constant GENERAL_ADMIN_HAT_ID = 0x420; // TODO: change to the actual hat id

contract Deploy is Script {
  function setUp() public virtual {}

  function run() public {
    vm.startBroadcast();
    new DSM(GENERAL_ADMIN_HAT_ID);
    vm.stopBroadcast();
  }
}

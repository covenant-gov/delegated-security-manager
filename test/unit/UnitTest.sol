// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DSM} from '@contracts/DSM.sol';
import {Test} from 'forge-std/Test.sol';

contract UnitTest is Test {
  // -- Setup --

  function setUp() public virtual {
    _mockHatMaxSupply(GENERAL_ADMIN_HAT_ID, 100);
    _mockHatMaxSupply(LOCAL_MANAGER_HAT_ID, 100);
    dsm = new DSM(GENERAL_ADMIN_HAT_ID, LOCAL_MANAGER_HAT_ID);
  }

  // -- Constants --

  address public constant HATS_ADDRESS = 0x3bc1A0Ad72417f2d411118085256fC53CBdDd137;
  uint256 public constant GENERAL_ADMIN_HAT_ID = 1;
  uint256 public constant INVALID_HAT_ID = 2;
  uint256 public constant LOCAL_MANAGER_HAT_ID = 3;
  uint256 public constant LOCAL_ADMIN_HAT_ID = 100;
  address public constant TEST_CONTRACT = address(0x123);
  address public constant GENERAL_ADMIN = address(0x456);
  address public constant LOCAL_MANAGER = address(0x789);
  address public constant LOCAL_ADMIN = address(0x937);
  uint64 public constant EXECUTION_PERIOD = 1 hours; // 3600

  // -- State variables --

  DSM public dsm;

  // -- Helper functions --

  function _mockHatMaxSupply(uint256 hatId, uint256 maxSupply) internal {
    vm.mockCall(HATS_ADDRESS, abi.encodeWithSignature('getHatMaxSupply(uint256)', hatId), abi.encode(maxSupply));
  }

  function _mockIsAdminOfHat(address user, uint256 hatId, bool isAdmin) internal {
    vm.mockCall(
      HATS_ADDRESS, abi.encodeWithSignature('isAdminOfHat(address,uint256)', user, hatId), abi.encode(isAdmin)
    );
  }

  // Helper to get contract registration status from storage
  function _isContractRegistered(address contractAddr) internal view returns (bool) {
    bytes32 slot = keccak256(abi.encode(contractAddr, uint256(0))); // slot 0 for _registeredContracts
    return vm.load(address(dsm), slot) != 0;
  }

  // Helper to get execution parameters from storage
  function _getExecutionParams(address contractAddr)
    internal
    view
    returns (uint256 localAdminHatId, uint64 executionPeriod, uint64 nextExpiry)
  {
    bytes32 slot = keccak256(abi.encode(contractAddr, uint256(1))); // slot 1 for _executionParams
    bytes32 data = vm.load(address(dsm), slot);

    // ExecutionParams struct layout: localAdminHatId (32 bytes), executionPeriod (8 bytes), nextExpiry (8 bytes)
    localAdminHatId = uint256(data);

    // Get executionPeriod and nextExpiry from next slot
    bytes32 nextSlot = vm.load(address(dsm), bytes32(uint256(slot) + 1));
    executionPeriod = uint64(uint256(nextSlot));
    nextExpiry = uint64(uint256(nextSlot) >> 64);
  }
}

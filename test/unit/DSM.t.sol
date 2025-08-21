// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DSM, IDSM} from '@contracts/DSM.sol';
import {UnitTest} from 'test/unit/UnitTest.sol';

contract DSMTest is UnitTest {
  // -- Modifiers --

  modifier isGeneralAdmin() {
    _mockIsAdminOfHat(GENERAL_ADMIN, GENERAL_ADMIN_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    _;
  }

  modifier isLocalAdmin() {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _;
  }

  // -- Constructor --

  function test_ConstructorSuccess() external {
    DSM testDsm = new DSM(GENERAL_ADMIN_HAT_ID, LOCAL_MANAGER_HAT_ID);
    assertEq(testDsm.GENERAL_ADMIN_HAT_ID(), GENERAL_ADMIN_HAT_ID);
    assertEq(testDsm.LOCAL_MANAGER_HAT_ID(), LOCAL_MANAGER_HAT_ID);
  }

  function test_ConstructorRevert_InvalidHatParam1() external {
    _mockHatMaxSupply(INVALID_HAT_ID, 0);
    vm.expectRevert(IDSM.NotActive.selector);
    new DSM(INVALID_HAT_ID, LOCAL_MANAGER_HAT_ID);
  }

  function test_ConstructorRevert_InvalidHatParam2() external {
    _mockHatMaxSupply(INVALID_HAT_ID, 0);
    vm.expectRevert(IDSM.NotActive.selector);
    new DSM(GENERAL_ADMIN_HAT_ID, INVALID_HAT_ID);
  }

  // -- View functions --

  function test_GeneralAdminHatId() external view {
    assertEq(dsm.GENERAL_ADMIN_HAT_ID(), GENERAL_ADMIN_HAT_ID);
  }

  // -- Unlock Contract Execution --

  function test_UnlockContractExecutionSuccess() external isGeneralAdmin {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);

    uint256 timestampBefore = block.timestamp;

    vm.expectEmit(true, false, false, false);
    emit IDSM.UnlockContractExecution(TEST_CONTRACT);

    dsm.unlockContractExecution(TEST_CONTRACT);
    vm.stopPrank();

    _mockIsAdminOfHat(LOCAL_ADMIN, LOCAL_ADMIN_HAT_ID, true);
    vm.prank(LOCAL_ADMIN);
    assertTrue(dsm.executable(TEST_CONTRACT, LOCAL_ADMIN));

    (,, uint64 nextExpiry) = _getExecutionParams(TEST_CONTRACT);
    assertEq(nextExpiry, timestampBefore + EXECUTION_PERIOD);
  }

  function test_UnlockContractExecutionRevert_NotRegistered() external isGeneralAdmin {
    vm.expectRevert(IDSM.NotRegistered.selector);
    dsm.unlockContractExecution(TEST_CONTRACT);
  }

  function test_UnlockContractExecutionRevert_NotAuthorized() external {
    _mockIsAdminOfHat(address(this), GENERAL_ADMIN_HAT_ID, false);
    vm.expectRevert(IDSM.NotAuthorized.selector);
    dsm.unlockContractExecution(TEST_CONTRACT);
  }

  // -- Lock Contract Execution --

  function test_LockContractExecutionSuccess() external isGeneralAdmin {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);

    // First unlock to set an expiry time
    dsm.unlockContractExecution(TEST_CONTRACT);
    vm.stopPrank();

    uint256 timestampAfterUnlock = block.timestamp;

    // Advance time to ensure we're in execution period
    vm.warp(timestampAfterUnlock + EXECUTION_PERIOD / 2);

    _mockIsAdminOfHat(LOCAL_ADMIN, LOCAL_ADMIN_HAT_ID, true);
    vm.prank(LOCAL_ADMIN);
    assertTrue(dsm.executable(TEST_CONTRACT, LOCAL_ADMIN));

    // Now lock the contract
    vm.expectEmit(true, false, false, false);
    emit IDSM.LockContractExecution(TEST_CONTRACT);

    vm.prank(GENERAL_ADMIN);
    dsm.lockContractExecution(TEST_CONTRACT);

    // Verify contract is now locked (nextExpiry should be current timestamp)
    (,, uint64 nextExpiry) = _getExecutionParams(TEST_CONTRACT);
    assertEq(nextExpiry, timestampAfterUnlock + EXECUTION_PERIOD / 2);

    // Verify executable returns false for local admin
    _mockIsAdminOfHat(LOCAL_ADMIN, LOCAL_ADMIN_HAT_ID, true);
    vm.prank(LOCAL_ADMIN);
    assertFalse(dsm.executable(TEST_CONTRACT, LOCAL_ADMIN));
  }

  function test_LockContractExecutionRevert_NotRegistered() external isGeneralAdmin {
    vm.expectRevert(IDSM.NotRegistered.selector);
    dsm.lockContractExecution(TEST_CONTRACT);
  }

  function test_LockContractExecutionRevert_NotAuthorized() external {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, GENERAL_ADMIN_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    vm.stopPrank();

    _mockIsAdminOfHat(address(this), GENERAL_ADMIN_HAT_ID, false);
    vm.expectRevert(IDSM.NotAuthorized.selector);
    dsm.lockContractExecution(TEST_CONTRACT);
  }

  // -- Register Contract --

  function test_RegisterContractSuccess() external isGeneralAdmin isLocalAdmin {
    vm.expectEmit(true, false, false, true);
    emit IDSM.RegisterContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);

    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);

    assertTrue(_isContractRegistered(TEST_CONTRACT));

    (uint256 localAdminHatId, uint64 executionPeriod, uint64 nextExpiry) = _getExecutionParams(TEST_CONTRACT);
    assertEq(localAdminHatId, LOCAL_ADMIN_HAT_ID);
    assertEq(executionPeriod, EXECUTION_PERIOD);
    assertEq(nextExpiry, 0);
  }

  function test_RegisterContractSuccess_ZeroExecutionPeriod() external isGeneralAdmin isLocalAdmin {
    vm.expectEmit(true, false, false, true);
    emit IDSM.RegisterContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, 0);

    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, 0);

    assertTrue(_isContractRegistered(TEST_CONTRACT));

    (uint256 localAdminHatId, uint64 executionPeriod, uint64 nextExpiry) = _getExecutionParams(TEST_CONTRACT);
    assertEq(localAdminHatId, LOCAL_ADMIN_HAT_ID);
    assertEq(executionPeriod, 0);
    assertEq(nextExpiry, 0);
  }

  function test_RegisterContractRevert_InactiveHat() external isGeneralAdmin {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 0);

    vm.expectRevert(IDSM.NotActive.selector);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);

    assertFalse(_isContractRegistered(TEST_CONTRACT));
  }

  function test_RegisterContractRevert_NotAuthorized() external {
    _mockIsAdminOfHat(address(this), GENERAL_ADMIN_HAT_ID, false);
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);

    vm.expectRevert(IDSM.NotAuthorized.selector);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);

    assertFalse(_isContractRegistered(TEST_CONTRACT));
  }

  // --- Update Contract ---

  function test_UpdateContractSuccess() external isGeneralAdmin isLocalAdmin {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    vm.stopPrank();

    uint64 newExecutionPeriod = EXECUTION_PERIOD + 1;
    uint256 newLocalAdminHatId = LOCAL_ADMIN_HAT_ID + 1;
    _mockHatMaxSupply(newLocalAdminHatId, 20);

    vm.expectEmit(true, false, false, true);
    emit IDSM.UpdateContract(TEST_CONTRACT, newLocalAdminHatId, newExecutionPeriod);

    (uint256 localAdminHatId0, uint64 executionPeriod0, uint64 nextExpiry0) = _getExecutionParams(TEST_CONTRACT);
    assertEq(localAdminHatId0, LOCAL_ADMIN_HAT_ID);
    assertEq(executionPeriod0, EXECUTION_PERIOD);
    assertEq(nextExpiry0, 0);

    _mockIsAdminOfHat(LOCAL_MANAGER, LOCAL_MANAGER_HAT_ID, true);
    vm.prank(LOCAL_MANAGER);
    dsm.updateContract(TEST_CONTRACT, newLocalAdminHatId, newExecutionPeriod);

    (uint256 localAdminHatId1, uint64 executionPeriod1, uint64 nextExpiry1) = _getExecutionParams(TEST_CONTRACT);
    assertEq(localAdminHatId1, newLocalAdminHatId);
    assertEq(executionPeriod1, newExecutionPeriod);
    assertEq(nextExpiry1, 0);
  }

  function test_UpdateContractRevert_NotAuthorized() external isGeneralAdmin {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    vm.stopPrank();

    _mockIsAdminOfHat(address(this), LOCAL_MANAGER_HAT_ID, false);
    vm.expectRevert(IDSM.NotAuthorized.selector);
    dsm.updateContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
  }

  function test_UpdateContractRevert_NotActiveHat() external isGeneralAdmin {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    vm.stopPrank();

    uint64 newExecutionPeriod = EXECUTION_PERIOD + 1;
    uint256 newLocalAdminHatId = LOCAL_ADMIN_HAT_ID + 1;
    _mockHatMaxSupply(newLocalAdminHatId, 0);

    _mockIsAdminOfHat(LOCAL_MANAGER, LOCAL_MANAGER_HAT_ID, true);
    vm.startPrank(LOCAL_MANAGER);
    vm.expectRevert(IDSM.NotActive.selector);
    dsm.updateContract(TEST_CONTRACT, newLocalAdminHatId, newExecutionPeriod);
    vm.stopPrank();
  }

  function test_UpdateContractRevert_NotRegistered() external {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(LOCAL_MANAGER, LOCAL_MANAGER_HAT_ID, true);
    vm.startPrank(LOCAL_MANAGER);
    vm.expectRevert(IDSM.NotRegistered.selector);
    dsm.updateContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
  }

  // -- Executable Function --

  function test_ExecutableReturnsFalse_ExpiredExecution() external {
    // Register and unlock contract
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, GENERAL_ADMIN_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    dsm.unlockContractExecution(TEST_CONTRACT);
    vm.stopPrank();

    // Fast forward past execution period
    vm.warp(block.timestamp + EXECUTION_PERIOD + 1);

    // Should return false since execution period expired
    _mockIsAdminOfHat(LOCAL_ADMIN, LOCAL_ADMIN_HAT_ID, true);
    vm.prank(LOCAL_ADMIN);
    assertFalse(dsm.executable(TEST_CONTRACT, LOCAL_ADMIN));
  }

  function test_ExecutableReturnsFalse_NotUnlocked() external {
    // Register contract but don't unlock
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, GENERAL_ADMIN_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    vm.stopPrank();

    // Should return false since nextExpiry is 0 (never unlocked)
    _mockIsAdminOfHat(LOCAL_ADMIN, LOCAL_ADMIN_HAT_ID, true);
    vm.prank(LOCAL_ADMIN);
    assertFalse(dsm.executable(TEST_CONTRACT, LOCAL_ADMIN));
  }

  // --- Params Function ---

  function test_ParamsFunctionSuccess() external {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, GENERAL_ADMIN_HAT_ID, true);
    vm.prank(GENERAL_ADMIN);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);

    (uint256 localAdminHatId, uint64 executionPeriod, uint64 nextExpiry, bool executable) = dsm.params(TEST_CONTRACT);
    assertEq(localAdminHatId, LOCAL_ADMIN_HAT_ID);
    assertEq(executionPeriod, EXECUTION_PERIOD);
    assertEq(nextExpiry, 0);
    assertFalse(executable);
  }

  function test_ParamsFunctionRevert_NotRegistered() external {
    vm.expectRevert(IDSM.NotRegistered.selector);
    dsm.params(TEST_CONTRACT);
  }

  function test_ParamsFunctionSuccess_AfterUnlock() external {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, GENERAL_ADMIN_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    dsm.unlockContractExecution(TEST_CONTRACT);
    vm.stopPrank();

    (uint256 localAdminHatId, uint64 executionPeriod, uint64 nextExpiry, bool executable) = dsm.params(TEST_CONTRACT);
    assertEq(localAdminHatId, LOCAL_ADMIN_HAT_ID);
    assertEq(executionPeriod, EXECUTION_PERIOD);
    assertEq(nextExpiry, block.timestamp + EXECUTION_PERIOD);
    assertTrue(executable);
  }

  function test_ParamsFunctionSuccess_AfterUnlockAndLock() external {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, GENERAL_ADMIN_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    dsm.unlockContractExecution(TEST_CONTRACT);
    vm.stopPrank();

    (uint256 localAdminHatId0, uint64 executionPeriod0, uint64 nextExpiry0, bool executable0) =
      dsm.params(TEST_CONTRACT);
    assertEq(localAdminHatId0, LOCAL_ADMIN_HAT_ID);
    assertEq(executionPeriod0, EXECUTION_PERIOD);
    assertEq(nextExpiry0, block.timestamp + EXECUTION_PERIOD);
    assertTrue(executable0);

    vm.warp(block.timestamp + EXECUTION_PERIOD / 2);

    (uint256 localAdminHatId1, uint64 executionPeriod1, uint64 nextExpiry1, bool executable1) =
      dsm.params(TEST_CONTRACT);
    assertEq(localAdminHatId1, LOCAL_ADMIN_HAT_ID);
    assertEq(executionPeriod1, EXECUTION_PERIOD);
    assertEq(nextExpiry1, block.timestamp + EXECUTION_PERIOD / 2);
    assertTrue(executable1);

    vm.prank(GENERAL_ADMIN);
    dsm.lockContractExecution(TEST_CONTRACT);

    (uint256 localAdminHatId2, uint64 executionPeriod2, uint64 nextExpiry2, bool executable2) =
      dsm.params(TEST_CONTRACT);
    assertEq(localAdminHatId2, LOCAL_ADMIN_HAT_ID);
    assertEq(executionPeriod2, EXECUTION_PERIOD);
    assertEq(nextExpiry2, block.timestamp);
    assertFalse(executable2);
  }

  function test_ParamsFunctionSuccess_AfterUpdate() external {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, GENERAL_ADMIN_HAT_ID, true);
    _mockIsAdminOfHat(LOCAL_MANAGER, LOCAL_MANAGER_HAT_ID, true);
    vm.prank(GENERAL_ADMIN);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);

    (uint256 localAdminHatId, uint64 executionPeriod, uint64 nextExpiry, bool executable) = dsm.params(TEST_CONTRACT);
    assertEq(localAdminHatId, LOCAL_ADMIN_HAT_ID);
    assertEq(executionPeriod, EXECUTION_PERIOD);
    assertEq(nextExpiry, 0);
    assertFalse(executable);

    uint64 newExecutionPeriod = EXECUTION_PERIOD + 1;
    uint256 newLocalAdminHatId = LOCAL_ADMIN_HAT_ID + 1;
    _mockHatMaxSupply(newLocalAdminHatId, 20);

    vm.prank(LOCAL_MANAGER);
    dsm.updateContract(TEST_CONTRACT, newLocalAdminHatId, newExecutionPeriod);

    (uint256 localAdminHatId1, uint64 executionPeriod1, uint64 nextExpiry1, bool executable1) =
      dsm.params(TEST_CONTRACT);
    assertEq(localAdminHatId1, newLocalAdminHatId);
    assertEq(executionPeriod1, newExecutionPeriod);
    assertEq(nextExpiry1, 0);
    assertFalse(executable1);
  }
}

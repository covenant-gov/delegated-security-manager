// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {UnitTest} from './UnitTest.sol';
import {DSM, IDSM} from '@contracts/DSM.sol';

contract DSMTest is UnitTest {
  // -- Modifiers --

  modifier isGeneralAdmin() {
    _mockIsAdminOfHat(GENERAL_ADMIN, VALID_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    _;
  }

  modifier isLocalAdmin() {
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _;
  }

  // -- Constructor --

  function test_ConstructorSuccess() external {
    _mockHatMaxSupply(VALID_HAT_ID, 100);
    DSM testDsm = new DSM(VALID_HAT_ID);
    assertEq(testDsm.GENERAL_ADMIN_HAT_ID(), VALID_HAT_ID);
  }

  function test_ConstructorRevert() external {
    _mockHatMaxSupply(INVALID_HAT_ID, 0);
    vm.expectRevert(IDSM.NotActive.selector);
    new DSM(INVALID_HAT_ID);
  }

  // -- View functions --

  function test_GeneralAdminHatId() external {
    assertEq(dsm.GENERAL_ADMIN_HAT_ID(), VALID_HAT_ID);
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
    _mockIsAdminOfHat(address(this), VALID_HAT_ID, false);
    vm.expectRevert(IDSM.NotAuthorized.selector);
    dsm.unlockContractExecution(TEST_CONTRACT);
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
    _mockIsAdminOfHat(address(this), VALID_HAT_ID, false);
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);

    vm.expectRevert(IDSM.NotAuthorized.selector);
    dsm.registerContract(TEST_CONTRACT, LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);

    assertFalse(_isContractRegistered(TEST_CONTRACT));
  }
}

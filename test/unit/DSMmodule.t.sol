// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {UnitTest} from './UnitTest.sol';

import {DSMmodule} from '@contracts/DSMmodule.sol';
import {IDSM} from '@interfaces/IDSM.sol';

contract DSMmoduleTest is UnitTest {
  DSMmodule public dsmModule;
  TestContract public testContract;

  function setUp() public override {
    super.setUp();

    dsmModule = new DSMmodule(address(dsm));

    // Deploy test contract that inherits DSMmodule
    testContract = new TestContract(address(dsm));
  }

  // -- Constructor --

  function test_ConstructorSuccess() external {
    DSMmodule testModule = new DSMmodule(address(dsm));
    assertEq(address(testModule.DSM()), address(dsm));
  }

  function test_ConstructorRevert_InvalidHat() external {
    // Create a mock DSM address and mock it to return 0 for GENERAL_ADMIN_HAT_ID
    address invalidDSM = address(0x888);
    vm.mockCall(invalidDSM, abi.encodeWithSignature('GENERAL_ADMIN_HAT_ID()'), abi.encode(0));

    vm.expectRevert(IDSM.NotActive.selector);
    new DSMmodule(invalidDSM);
  }

  // -- View Functions --

  function test_DSM() external {
    assertEq(address(dsmModule.DSM()), address(dsm));
  }

  // -- onlyAdmin Modifier --

  function test_OnlyAdminSuccess() external {
    // Register test contract in DSM
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, VALID_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    dsm.registerContract(address(testContract), LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    dsm.unlockContractExecution(address(testContract));
    vm.stopPrank();

    // Call as local admin
    _mockIsAdminOfHat(LOCAL_ADMIN, LOCAL_ADMIN_HAT_ID, true);
    vm.prank(LOCAL_ADMIN);
    testContract.adminOnlyFunction();
  }

  function test_OnlyAdminRevert_ExecutableReturnsFalse() external {
    // Register test contract but don't unlock execution (expired)
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, VALID_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    dsm.registerContract(address(testContract), LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    vm.stopPrank();

    // Call as local admin (but execution window expired)
    _mockIsAdminOfHat(LOCAL_ADMIN, LOCAL_ADMIN_HAT_ID, true);
    vm.prank(LOCAL_ADMIN);
    vm.expectRevert(IDSM.NotAuthorized.selector);
    testContract.adminOnlyFunction();
  }

  function test_OnlyAdminRevert_NotRegistered() external {
    // Don't register test contract
    _mockIsAdminOfHat(LOCAL_ADMIN, LOCAL_ADMIN_HAT_ID, true);
    vm.prank(LOCAL_ADMIN);
    vm.expectRevert(IDSM.NotRegistered.selector);
    testContract.adminOnlyFunction();
  }

  function test_OnlyAdminRevert_NotAuthorized() external {
    // Register test contract but call as non-admin
    _mockHatMaxSupply(LOCAL_ADMIN_HAT_ID, 100);
    _mockIsAdminOfHat(GENERAL_ADMIN, VALID_HAT_ID, true);
    vm.startPrank(GENERAL_ADMIN);
    dsm.registerContract(address(testContract), LOCAL_ADMIN_HAT_ID, EXECUTION_PERIOD);
    dsm.unlockContractExecution(address(testContract));
    vm.stopPrank();

    // Call as non-admin
    _mockIsAdminOfHat(address(this), LOCAL_ADMIN_HAT_ID, false);
    vm.expectRevert(IDSM.NotAuthorized.selector);
    testContract.adminOnlyFunction();
  }
}

// Helper contract to test the onlyAdmin modifier
contract TestContract is DSMmodule {
  constructor(address _dsm) DSMmodule(_dsm) {}

  function adminOnlyFunction() external onlyAdmin {
    // This function is used to test the onlyAdmin modifier
  }
}

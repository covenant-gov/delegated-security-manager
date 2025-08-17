// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IDSM} from '@interfaces/IDSM.sol';
import {IHats} from 'hats-core/Interfaces/IHats.sol';

contract DSM is IDSM {
  /// @notice Hats protocol v1 contract CREATE2 address on all networks
  IHats internal constant _HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);

  /// @inheritdoc IDSM
  uint256 public immutable GENERAL_ADMIN_HAT_ID;

  mapping(address _contract => bool _registered) internal _registeredContracts;
  mapping(address _contract => ExecutionParams _conditions) internal _executionParams;

  /// @notice Modifier to check if the caller is the general admin
  modifier onlyGeneralAdmin() {
    if (!_HATS.isAdminOfHat(msg.sender, GENERAL_ADMIN_HAT_ID)) revert NotAuthorized();
    _;
  }

  /// @notice Modifier to check if the caller is the contract admin
  modifier onlyContractAdmin(address _contract, address _caller) {
    if (!_registeredContracts[_contract]) revert NotRegistered();
    if (!_HATS.isAdminOfHat(_caller, _executionParams[_contract].localAdminHatId)) revert NotAuthorized();
    _;
  }

  /// @notice Modifier to check if the contract is registered
  modifier onlyRegistered(address _contract) {
    if (!_registeredContracts[_contract]) revert NotRegistered();
    _;
  }

  /// @notice Modifier to check if the hat is active
  modifier onlyActiveHat(uint256 _hatId) {
    if (_HATS.getHatMaxSupply(_hatId) == 0) revert NotActive();
    _;
  }

  /**
   * @notice Constructor to initialize the DSM
   * @param _generalAdminHatId The ID of the general admin hat
   */
  constructor(uint256 _generalAdminHatId) {
    if (_HATS.getHatMaxSupply(_generalAdminHatId) == 0) revert NotActive();
    GENERAL_ADMIN_HAT_ID = _generalAdminHatId;
  }

  /// @inheritdoc IDSM
  function unlockContractExecution(address _contract) external onlyGeneralAdmin onlyRegistered(_contract) {
    _executionParams[_contract].nextExpiry = uint64(block.timestamp + _executionParams[_contract].executionPeriod);
    emit UnlockContractExecution(_contract);
  }

  /// @inheritdoc IDSM
  function registerContract(
    address _contract,
    uint256 _localAdminHatId,
    uint64 _executionPeriod
  ) external onlyGeneralAdmin onlyActiveHat(_localAdminHatId) {
    _registeredContracts[_contract] = true;
    _executionParams[_contract] =
      ExecutionParams({localAdminHatId: _localAdminHatId, executionPeriod: _executionPeriod, nextExpiry: uint64(0)});
    emit RegisterContract(_contract, _localAdminHatId, _executionPeriod);
  }

  /// @inheritdoc IDSM
  function executable(
    address _contract,
    address _caller
  ) external view onlyContractAdmin(_contract, _caller) returns (bool _permitted) {
    if (block.timestamp < _executionParams[_contract].nextExpiry) _permitted = true;
    else _permitted = false;
  }
}

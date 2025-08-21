// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IDSM} from '@interfaces/IDSM.sol';
import {IHats} from 'hats-core/Interfaces/IHats.sol';

contract DSM is IDSM {
  /// @notice Hats protocol v1 contract CREATE2 address on all networks
  IHats internal constant _HATS = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);

  /// @inheritdoc IDSM
  uint256 public immutable GENERAL_ADMIN_HAT_ID;
  /// @inheritdoc IDSM
  uint256 public immutable LOCAL_MANAGER_HAT_ID;

  mapping(address _contract => bool _registered) internal _registeredContracts;
  mapping(address _contract => ExecutionParams _conditions) internal _executionParams;

  /// @notice Modifier to check if the caller is the general admin
  modifier onlyGeneralAdmin() {
    if (!_HATS.isAdminOfHat(msg.sender, GENERAL_ADMIN_HAT_ID)) revert NotAuthorized();
    _;
  }

  /// @notice Modifier to check if the caller is the general admin
  modifier onlyLocalManager() {
    if (!_HATS.isAdminOfHat(msg.sender, LOCAL_MANAGER_HAT_ID)) revert NotAuthorized();
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
    if (!_isActiveHat(_hatId)) revert NotActive();
    _;
  }

  /**
   * @notice Constructor to initialize the DSM
   * @param _generalAdminHatId The ID of the general admin hat
   */
  constructor(uint256 _generalAdminHatId, uint256 _localManagerHatId) {
    if (!_isActiveHat(_generalAdminHatId)) revert NotActive();
    if (!_isActiveHat(_localManagerHatId)) revert NotActive();
    GENERAL_ADMIN_HAT_ID = _generalAdminHatId;
    LOCAL_MANAGER_HAT_ID = _localManagerHatId;
  }

  // --- Logic --- //

  /// @inheritdoc IDSM
  function unlockContractExecution(address _contract) external onlyGeneralAdmin onlyRegistered(_contract) {
    _executionParams[_contract].nextExpiry = uint64(block.timestamp + _executionParams[_contract].executionPeriod);
    emit UnlockContractExecution(_contract);
  }

  /// @inheritdoc IDSM
  function lockContractExecution(address _contract) external onlyGeneralAdmin onlyRegistered(_contract) {
    _executionParams[_contract].nextExpiry = uint64(block.timestamp);
    emit LockContractExecution(_contract);
  }

  /// @inheritdoc IDSM
  function registerContract(
    address _contract,
    uint256 _localAdminHatId,
    uint64 _executionPeriod
  ) external onlyGeneralAdmin onlyActiveHat(_localAdminHatId) {
    if (_isRegistered(_contract)) revert Registered();
    _registeredContracts[_contract] = true;
    _updateContract(_contract, _localAdminHatId, _executionPeriod);
    emit RegisterContract(_contract, _localAdminHatId, _executionPeriod);
  }

  /// @inheritdoc IDSM
  function updateContract(
    address _contract,
    uint256 _localAdminHatId,
    uint64 _executionPeriod
  ) external onlyLocalManager onlyActiveHat(_localAdminHatId) {
    if (!_isRegistered(_contract)) revert NotRegistered();
    _updateContract(_contract, _localAdminHatId, _executionPeriod);
    emit UpdateContract(_contract, _localAdminHatId, _executionPeriod);
  }

  /// @inheritdoc IDSM
  function executable(
    address _contract,
    address _caller
  ) external view onlyContractAdmin(_contract, _caller) returns (bool _permitted) {
    _permitted = _isExecutable(_contract);
  }

  /// @inheritdoc IDSM
  function params(address _contract)
    external
    view
    returns (uint256 _localAdminHatId, uint64 _executionPeriod, uint64 _nextExpiry, bool _executable)
  {
    if (!_isRegistered(_contract)) revert NotRegistered();
    ExecutionParams memory _params = _executionParams[_contract];
    _localAdminHatId = _params.localAdminHatId;
    _executionPeriod = _params.executionPeriod;
    _nextExpiry = _params.nextExpiry;
    _executable = _isExecutable(_contract);
  }

  // --- Internal --- //

  /**
   * @notice Internal function to update the contract
   * @param _contract The address of the contract
   * @param _localAdminHatId The ID of the local admin hat
   * @param _executionPeriod The period of the execution
   */
  function _updateContract(address _contract, uint256 _localAdminHatId, uint64 _executionPeriod) internal {
    _executionParams[_contract] =
      ExecutionParams({localAdminHatId: _localAdminHatId, executionPeriod: _executionPeriod, nextExpiry: uint64(0)});
  }

  /**
   * @notice Internal function to check if the contract is executable
   * @param _contract The address of the contract
   * @return _permitted whether the execution window is open
   */
  function _isExecutable(address _contract) internal view returns (bool _permitted) {
    if (block.timestamp < _executionParams[_contract].nextExpiry) _permitted = true;
    else _permitted = false;
  }

  /**
   * @notice Internal function to check if the contract is registered
   * @param _contract The address of the contract
   * @return bool True if the contract is registered, false otherwise
   */
  function _isRegistered(address _contract) internal view returns (bool) {
    return _registeredContracts[_contract];
  }

  /**
   * @notice Internal function to check if the hat is active
   * @param _hatId The ID of the hat
   * @return bool True if the hat is active, false otherwise
   */
  function _isActiveHat(uint256 _hatId) internal view returns (bool) {
    return _HATS.getHatMaxSupply(_hatId) != 0;
  }
}

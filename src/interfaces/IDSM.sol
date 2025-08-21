// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/**
 * @title Delegated Security Manager (DSM) Contract
 * @author Bread
 * @notice This is a security manager contract that allows for the delegation of security using Hats protocol
 */
interface IDSM {
  /**
   * @notice Parameters for the execution of a contract
   * @param localAdminHatId The ID of the local admin hat
   * @param executionPeriod The period of execution by local admin hat
   * @param nextExpiry The next expiry of the execution
   */
  struct ExecutionParams {
    uint256 localAdminHatId;
    uint64 executionPeriod;
    uint64 nextExpiry;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Emitted when a contract is registered
   * @param _contract The address of the contract
   * @param _localAdminHatId The ID of the local admin hat
   * @param _executionPeriod The period of the execution
   */
  event RegisterContract(address indexed _contract, uint256 _localAdminHatId, uint64 _executionPeriod);

  /**
   * @notice Emitted when a contract is updated
   * @param _contract The address of the contract
   * @param _localAdminHatId The ID of the local admin hat
   * @param _executionPeriod The period of the execution
   */
  event UpdateContract(address indexed _contract, uint256 _localAdminHatId, uint64 _executionPeriod);

  /**
   * @notice Emitted when the execution of a contract is unlocked
   * @param _contract The address of the contract
   */
  event UnlockContractExecution(address indexed _contract);

  /**
   * @notice Emitted when the execution of a contract is locked
   * @param _contract The address of the contract
   */
  event LockContractExecution(address indexed _contract);

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when the caller is not authorized
  error NotAuthorized();
  /// @notice Thrown when the contract is not registered
  error NotRegistered();
  /// @notice Thrown when the contract is already registered
  error Registered();
  /// @notice Thrown when the hat is not active
  error NotActive();

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Unlocks the execution of a contract for the duration of the execution period
   * @dev Only the GENERAL_ADMIN_HAT_ID can unlock a contract
   * @param _contract The address of the contract to unlock
   */
  function unlockContractExecution(address _contract) external;

  /**
   * @notice Locks the execution of a contract
   * @dev Only the GENERAL_ADMIN_HAT_ID can lock a contract
   * @dev Contract will automatically lock after execution period expires if not locked manually
   * @param _contract The address of the contract to lock
   */
  function lockContractExecution(address _contract) external;

  /**
   * @notice Registers a contract with the DSM
   * @dev Only the GENERAL_ADMIN_HAT_ID can register a contract
   * @param _contract The address of the contract to register
   * @param _localAdminHatId The ID of the local admin hat
   * @param _executionPeriod The period of the execution
   */
  function registerContract(address _contract, uint256 _localAdminHatId, uint64 _executionPeriod) external;

  /**
   * @notice Updates a contract with the DSM
   * @dev Only the LOCAL_MANAGER_HAT_ID can update a contract (this separation from the general admin enhances security)
   * @param _contract The address of the contract to update
   * @param _localAdminHatId The ID of the local admin hat
   * @param _executionPeriod The period of the execution
   */
  function updateContract(address _contract, uint256 _localAdminHatId, uint64 _executionPeriod) external;

  /**
   * @notice Checks if a contract is executable
   * @dev Only the local contract admin can call this via DSMmodule contract
   * @param _contract The address of the contract to check
   * @param _caller The address of the caller
   * @return _permitted True if the contract is executable, false otherwise
   */
  function executable(address _contract, address _caller) external view returns (bool _permitted);

  /**
   * @notice Returns the parameters of a contract
   * @param _contract The address of the contract to check
   * @return _localAdminHatId The ID of the local admin hat
   * @return _executionPeriod The period of the execution
   * @return _nextExpiry The next expiry of the execution
   * @return _executable Whether the contract is executable
   */
  function params(address _contract)
    external
    view
    returns (uint256 _localAdminHatId, uint64 _executionPeriod, uint64 _nextExpiry, bool _executable);

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Returns the general admin hat ID for the DSM
   * @return _generalAdminHatId The ID of the general admin hat
   */
  function GENERAL_ADMIN_HAT_ID() external view returns (uint256 _generalAdminHatId);

  /**
   * @notice Returns the local manager hat ID for the DSM
   * @return _localManagerHatId The ID of the local manager hat
   */
  function LOCAL_MANAGER_HAT_ID() external view returns (uint256 _localManagerHatId);
}

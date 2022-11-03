pragma solidity ^0.8.16;

import "./InterfacesV1.sol";
import "forge-std/Test.sol";

contract ChainInsightGovernanceProxyV1 is
    ChainInsightGovernanceStorageV1,
    ChainInsightGovernanceEventsV1
{
    /**
     * @param implementation_ The address for implementaion for delegationcall.
     * @param executorContract_ The address for transaction executor contract which passed by votes.
     * @param sbtContract_ The address for sbtContract(sbt.sol)
     * @param admin_ the admin address of govenance. This admin will be only chosen by votes.
     * @param vetoer_ the address of person who has rights to veto proposal. TODO: This function shoud not be included.
     * @param executingGracePeriod_ the period proposal is lasting. The proposal transaction must be executed before this period is passed.
     * @param executingDelay_ the proposal is executed after queue function is called and this period is passed.
     * @param votingPeriod_ The voting period
     * @param votingDelay_ voting delay
     * @param proposalThreshold_ The proposal is passed if the number of votes obtained is greater than this threshold.
     */
    constructor(
        address implementation_,
        address executorContract_,
        address sbtContract_,
        address admin_,
        address vetoer_,
        uint256 executingGracePeriod_,
        uint256 executingDelay_,
        uint256 votingPeriod_,
        uint256 votingDelay_,
        uint256 proposalThreshold_
    ) {
        // Admin set to msg.sender for initialization
        admin = msg.sender;
        delegateTo(
            implementation_,
            abi.encodeWithSignature(
                "initialize(address,address,address,uint256,uint256,uint256,uint256,uint256)",
                executorContract_,
                sbtContract_,
                vetoer_,
                executingGracePeriod_,
                executingDelay_,
                votingPeriod_,
                votingDelay_,
                proposalThreshold_
            )
        );

        _setImplementation(implementation_);

        admin = admin_;
    }

    /**
     * @notice Called by the admin to update the implementation of the delegator
     * @param implementation_ The address of the new implementation for delegation
     */
    function _setImplementation(address implementation_) public {
        require(
            msg.sender == admin,
            "NounsDAOProxy::_setImplementation: admin only"
        );

        require(
            implementation_ != address(0),
            "NounsDAOProxy::_setImpelementation: invalid implementation address"
        );
        require(
            implementation_ != implementation,
            "NounsDAOProxy::_setImpelementation: implementation address must be different from old one"
        );

        address oldImplementation = implementation;
        implementation = implementation_;

        emit NewImplementation(oldImplementation, implementation);
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     */
    function _setPendingAdmin(address newPendingAdmin) external {
        require(
            msg.sender == address(this),
            "ProxyV1::_setPendingAdmin: pending admin can be setted only through voting"
        );

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
     * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
     * @dev Admin function for pending admin to accept role and update admin
     */
    function _acceptAdmin() external {
        require(
            msg.sender == pendingAdmin,
            "ProxyV1::_acceptAdmin: pending admin only"
        );

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    /**
     * @notice Internal method to delegate execution to another contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param callee The contract to delegatecall
     * @param data The raw data to delegatecall
     */
    function delegateTo(address callee, bytes memory data) internal {
        (bool success, bytes memory returnData) = callee.delegatecall(data);

        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
    }

    /**
     * @dev Delegates execution to an implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    function _fallback() internal {
        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize())

            switch success
            case 0 {
                revert(free_mem_ptr, returndatasize())
            }
            default {
                return(free_mem_ptr, returndatasize())
            }
        }
    }

    /**
     * @dev Fallback function that delegates calls to the `implementation`. Will return if no other
     * function in the contract matches the call data
     */
    fallback() external payable {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to `implementation`. Will run if call data
     * is empty.
     */
    receive() external payable {
        _fallback();
    }
}

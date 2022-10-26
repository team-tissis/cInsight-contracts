pragma solidity ^0.8.16;

import './InterfacesV1.sol';

contract ChainInsightExecutorV1 is IChainInsightExecutor {
    // event NewPendingLogicContract(address indexed newGovContract);

    address public logicAddress;
    // address public pendingLogicContract;

    mapping(bytes32 => bool) public queuedTransactions;

    constructor(address logicAddress_) {
        logicAddress = logicAddress_;
    }

    // function acceptLogicAddress() external {
    function setLogicAddress(address newLogicAddress) external {
        // require(msg.sender == pendingGovContract, 'Executor::acceptGovContract: Call must come from pendingGovContract.');
        // logicAddress = msg.sender;
        // pendingLogicAddress = address(0);
        require(
            msg.sender == address(this),
            'Executor::setPendingLogicAddress: Call must come from Executor.'
        );

        address oldLogicAddress = logicAddress;
        logicAddress = newLogicAddress;

        emit NewLogicAddress(oldLogicAddress, newLogicAddress);
    }

    /** 
     * function setPendingLogicAddress(address pendingLogicAddress_) public {
     *     require(
     *         msg.sender == address(this),
     *         'Executor::setPendingLogicAddress: Call must come from Executor.'
     *     );
     *     pendingLogicAddress = pendingLogicAddress_;

     *     emit NewPendingLogicAddress(pendingLogicAddress);
     * }
     */

    function transactionIsQueued(bytes32 txHash) external view returns (bool) {
        return queuedTransactions[txHash];
    }

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32) {
        require(msg.sender == logicAddress, 'Executor::queueTransaction: Call must come from Logic.');

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external {
        require(msg.sender == logicAddress, 'Executor::cancelTransaction: Call must come from Logic.');

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta,
        uint256 executingGracePeriod
    ) external payable returns (bytes memory) {
        require(msg.sender == logicAddress, 'Executor::executeTransaction: Call must come from Logic.');
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

        require(queuedTransactions[txHash], "Executor::executeTransaction: Transaction hasn't been queued.");

        require(
            getBlockTimestamp() >= eta,
            "Executor::executeTransaction: Transaction hasn't surpassed time lock."
        );
        require(
            getBlockTimestamp() <= eta + executingGracePeriod,
            'Executor::executeTransaction: Transaction is stale.'
        );

        // delete transaction from queue
        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            // bytes4(...) is function selector
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        /// @notice The first four bytes correspond to function selector defined else clause
        (bool success, bytes memory returnData) = target.call{ value: value }(callData);
        require(success, 'Executor::executeTransaction: Transaction executed reverted.');

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    receive() external payable {}

    fallback() external payable {}
}

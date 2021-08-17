//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";

contract Multisig {
  event CreateTransaction(address owner, uint256 transactionId);
  event SignTransaction(address owner, uint256 transactionId);
  event ExecuteTransaction(address owner, uint256 transactionId);

  using Counters for Counters.Counter;
  Counters.Counter private transactionId;

  // owner mapping
  mapping(address => bool) private owner;

  // owners count
  uint96 private ownerCount;

  // number of signatures required
  uint96 private numberOfSignatures;

  // Transaction object
  struct Transaction {
    address to;
    uint256 value;
    bytes data;
    uint96 signatures;
  }

  // id by transaction object
  mapping(uint256 => Transaction) private transactions;

  // mapping to check the signatures of each user for each transactions
  // id to owners to isSigned boolean
  mapping(uint256 => mapping(address => bool)) private isSigned;

  modifier onlyOwner() {
    require(owner[msg.sender], "Not Owner");
    _;
  }

  constructor(address[] memory _owners) {
    require(_owners.length != 3, "3 owners required");

    // defaults
    ownerCount = 3;
    numberOfSignatures = 2;

    // update mapping
    for (uint8 i = 0; i < _owners.length; i++) {
      owner[_owners[i]] = true;
    }
  }

  function addOwner(address _owner) external onlyOwner {
    require(_owner != address(0), "Invalid Address");
    ownerCount++;
    owner[_owner] = true;
  }

  function setMininumSignaturesRequired(uint96 _minimumSignatures)
    external
    onlyOwner
  {
    require(
      _minimumSignatures > ownerCount,
      "Number should be <= number of owners"
    );
    numberOfSignatures = _minimumSignatures;
  }

  function createTransaction(
    address _to,
    uint256 _value,
    bytes memory _data
  ) external onlyOwner {
    Transaction memory transaction = Transaction({
      to: _to,
      value: _value,
      data: _data,
      signatures: 1
    });
    transactions[transactionId.current()] = transaction;
    isSigned[transactionId.current()][msg.sender] = true;
    emit CreateTransaction(msg.sender, transactionId.current());
    transactionId.increment();
  }

  function signTransaction(uint256 _transactionId) external onlyOwner {
    require(_transactionId < transactionId.current(), "Invalid transaction ID");
    require(
      isSigned[_transactionId][msg.sender] == true,
      "Transaction Already Signed"
    );
    Transaction storage transaction = transactions[_transactionId];
    transaction.signatures++;
    isSigned[_transactionId][msg.sender] = true;
    emit SignTransaction(msg.sender, _transactionId);
  }

  function executeTransaction(uint256 _transactionId) public onlyOwner {
    Transaction storage transaction = transactions[_transactionId];
    // check if atleast minimum required signs are present
    require(
      transaction.signatures < numberOfSignatures,
      "Insufficient signatures"
    );
    (bool executed, ) = transaction.to.call{ value: transaction.value }(
      transaction.data
    );
    if (!executed) {
      revert();
    }
    emit ExecuteTransaction(msg.sender, _transactionId);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./TransactionOwner.sol";

contract TransactionManager is TransactionOwner, ReentrancyGuard {
  using Address for address payable;
  using SafeMath  for uint256;
  using SafeERC20 for IERC20;

  enum TransactionType { ETHToToken, TokenToETH, TokenToToken }
  enum Status { Empty, Deposited, Withdrawn }

  //events ===========
  event eventCreateNewTransaction(
    bytes32 transactionId,
    uint8 transactionType,
    uint256 createdAt,
    uint256 expiresAt,
    address user0,
    address token0,
    uint256 token0Amount,
    address user1,
    address token1,
    uint256 token1Amount,
    address refer
  );

  event eventUserDeposit(
    bytes32 transactionId,
    address user0,
    address user,
    address token,
    uint256 tokenAmount,
    uint256 depositAt
  );

  event eventUserWithdraw(
    bytes32 transactionId,
    address user0,
    address user,
    address token,
    uint256 tokenAmount,
    uint256 withdrawAt
  );

  struct Transaction {
    bool    isExist;
    TransactionType transactionType;
    address user0;
    address token0;
    uint256 token0Amount;
    address user1;
    address token1;
    uint256 token1Amount;
    uint256 createdAt;
    uint256 expiresAt;
    Status user0Status;
    Status user1Status;
    address refer;
  }

  mapping(string=>Transaction) internal transactions;

  modifier onlyUser() {
    require(_msgSender() != owner(), "Owner not allowed.");
    _;
  }

  receive() external payable { }

  fallback() external payable { }

  function createNewTransaction(
    bytes32 transactionId,
    uint8 transactionType,
    address token0,
    uint256 token0Amount,
    address user1,
    address token1,
    uint256 token1Amount,
    uint256 proposedPendingTime,
    address refer
  ) external onlyUser nonReentrant {

    require(contractEnabled == true, "contract is not enabled");
    require(uint8(TransactionType.TokenToToken) >= transactionType, "Invalid transaction type");
    require(token0 != token1, 'Tokens cannot be equal');

    address user0 = _msgSender();
    require(user0 != user1, 'Users cannot be equal');
    require(user1 != address(0), "User cannot be zero address");

    string memory transactionKey = _returnTransactionKey(transactionId, user0);
    require(transactions[transactionKey].isExist != true, "Transaction Exists");

    uint256 pendingTime = defaultPendingTime;

    if (proposedPendingTime != 0) {
      require(proposedPendingTime >= minPendingTime, "Pending time cannot be less than minimum");
      require(proposedPendingTime <= maxPendingTime, "Pending time cannot be more than maximum");
      pendingTime = proposedPendingTime;
    }

    Transaction memory newTransaction;
    newTransaction.isExist = true;
    newTransaction.transactionType = TransactionType(transactionType);
    newTransaction.user0 = user0;
    newTransaction.token0 = transactionType == uint8(TransactionType.ETHToToken) ? address(0) : token0;
    newTransaction.token0Amount = token0Amount;
    newTransaction.user1 = user1;
    newTransaction.token1 = transactionType == uint8(TransactionType.TokenToETH) ? address(0) : token1;
    newTransaction.token1Amount = token1Amount;
    newTransaction.createdAt = block.timestamp;
    newTransaction.expiresAt = block.timestamp + (pendingTime * 1 hours);
    newTransaction.user0Status = Status.Empty;
    newTransaction.user1Status = Status.Empty;

    if (refer != address(0) && referEnabled) {
      newTransaction.refer = refer;
    }

    transactions[transactionKey] = newTransaction;
    emit eventCreateNewTransaction(
      transactionId,
      uint8(newTransaction.transactionType),
      newTransaction.createdAt,
      newTransaction.expiresAt,
      newTransaction.user0,
      newTransaction.token0,
      newTransaction.token0Amount,
      newTransaction.user1,
      newTransaction.token1,
      newTransaction.token1Amount,
      newTransaction.refer
    );
  }

  function depositUser0(
    bytes32 transactionId
  ) external payable nonReentrant {

    require(contractEnabled == true);

    string memory transactionKey = _returnTransactionKey(transactionId, _msgSender());
    require(transactions[transactionKey].isExist, "Invalid transaction");

    Transaction memory transaction = transactions[transactionKey];

    require(transaction.user0 == _msgSender(), "Invalid permissions");
    require(block.timestamp < transaction.expiresAt, "Transaction expired");
    require(transaction.user0Status == Status.Empty, "Deposit done");

    transactions[transactionKey].user0Status = Status.Deposited;

    if (transaction.transactionType == TransactionType.ETHToToken) {
      require(msg.value >= transaction.token0Amount, "Insufficient deposit");
    }

    if (transaction.transactionType != TransactionType.ETHToToken) {
      // check for tax tokens where amount received != transfer amount
      uint256 balanceBefore = IERC20(transaction.token0).balanceOf(address(this));
      IERC20(transaction.token0).safeTransferFrom(_msgSender(), address(this), transaction.token0Amount);
      uint256 balanceAfter = IERC20(transaction.token0).balanceOf(address(this));
      transaction.token0Amount = balanceAfter.sub(balanceBefore);
    }

    emit eventUserDeposit(
      transactionId,
      transaction.user0,
      transaction.user0,
      transaction.token0,
      transaction.token0Amount,
      block.timestamp
    );
  }

  function depositUser1(
    bytes32 transactionId,
    address user0
  ) external payable nonReentrant {

    require(contractEnabled == true, "Contract is not enabled");
    string memory transactionKey = _returnTransactionKey(transactionId, user0);

    require(transactions[transactionKey].isExist, "Invalid transaction");
    Transaction memory transaction = transactions[transactionKey];

    require(transaction.user1 == _msgSender(), "Invalid permissions");
    require(transaction.user0 == user0, "Invalid transaction");
    require(block.timestamp < transaction.expiresAt, "Transaction expired");
    require(transaction.user1Status == Status.Empty, "Deposit done");

    transactions[transactionKey].user1Status = Status.Deposited;

    if (transaction.transactionType == TransactionType.TokenToETH) {
      require(msg.value >= transaction.token1Amount, "Insufficient deposit");
    }

    if (transaction.transactionType != TransactionType.TokenToETH) {
      // check for tax tokens where amount received != transfer amount
      uint256 balanceBefore = IERC20(transaction.token1).balanceOf(address(this));
      IERC20(transaction.token1).safeTransferFrom(_msgSender(), address(this), transaction.token1Amount);
      uint256 balanceAfter = IERC20(transaction.token1).balanceOf(address(this));
      transaction.token1Amount = balanceAfter.sub(balanceBefore);
    }

    emit eventUserDeposit(
      transactionId,
      transaction.user0,
      transaction.user1,
      transaction.token1,
      transaction.token1Amount,
      block.timestamp
    );
  }

  function withdrawUser0(
    bytes32 transactionId
  ) external onlyUser nonReentrant {

    require(contractEnabled == true);
    string memory transactionKey = _returnTransactionKey(transactionId, _msgSender());
    require(transactions[transactionKey].isExist, "Invalid transaction");

    Transaction memory transaction = transactions[transactionKey];

    require(transaction.user0 == _msgSender(), "Invalid permissions");
    require(transaction.user0Status == Status.Deposited, "Withdraw not permitted");
    transactions[transactionKey].user0Status = Status.Withdrawn;

    // transaction not expired, user can withdraw ===========================
    if (block.timestamp <= transaction.expiresAt) {

      require(uint8(transaction.user1Status) >= uint8(Status.Deposited), "Other user must deposit");

      // custom fee or default fee ======
      uint256 feeToUse = defaultFee;
      string memory pairKey = _appendAddresses(transaction.token0, transaction.token1);
      if (pairs[pairKey].isExist == true) {
        feeToUse = pairs[pairKey].fee;
      }

      uint256 commissionAmount = transaction.token1Amount.mul(feeToUse).div(feeDivider);
      uint256 referCommission = commissionAmount.mul(referFee).div(feeDivider);

      // if there is a refer address, give them their cut
      if (transactions[transactionKey].refer != address(0) && referEnabled) {

        if (transaction.transactionType == TransactionType.TokenToETH) {
          payable(_msgSender()).transfer(transaction.token1Amount.sub(commissionAmount));
          payable(commissionAddress).transfer(commissionAmount.sub(referCommission));
          payable(transactions[transactionKey].refer).transfer(referCommission);
        }

        if (transaction.transactionType != TransactionType.TokenToETH) {
          IERC20(transaction.token1).safeTransfer(_msgSender(), transaction.token1Amount.sub(commissionAmount));
          IERC20(transaction.token1).safeTransfer(commissionAddress, commissionAmount.sub(referCommission));
          IERC20(transaction.token1).safeTransfer(transactions[transactionKey].refer, referCommission);
        }
      } else {
        if (transaction.transactionType == TransactionType.TokenToETH) {
          payable(_msgSender()).transfer(transaction.token1Amount.sub(commissionAmount));
          payable(commissionAddress).transfer(commissionAmount);
        }

        if (transaction.transactionType != TransactionType.TokenToETH) {
          IERC20(transaction.token1).safeTransfer(_msgSender(), transaction.token1Amount.sub(commissionAmount));
          IERC20(transaction.token1).safeTransfer(commissionAddress, commissionAmount);
        }
      }

      emit eventUserWithdraw(
        transactionId,
        transaction.user0,
        transaction.user0,
        transaction.token1,
        transaction.token1Amount.sub(commissionAmount),
        block.timestamp
      );
    }

    // expired: user can only get their original deposit back ===============
    if (block.timestamp > transaction.expiresAt) {

      if (transaction.transactionType == TransactionType.ETHToToken) {
        payable(_msgSender()).transfer(transaction.token0Amount);
      }

      if (transaction.transactionType != TransactionType.ETHToToken) {
        IERC20(transaction.token0).safeTransfer(_msgSender(), transaction.token0Amount);
      }

      emit eventUserWithdraw(
        transactionId,
        transaction.user0,
        transaction.user0,
        transaction.token0,
        transaction.token0Amount,
        block.timestamp
      );
    }
  }

  function withdrawUser1(
    bytes32 transactionId,
    address user0
  ) external onlyUser nonReentrant {

    require(contractEnabled == true);
    string memory transactionKey = _returnTransactionKey(transactionId, user0);
    require(transactions[transactionKey].isExist, "Invalid transaction");
    Transaction memory transaction = transactions[transactionKey];

    require(transaction.user1 == _msgSender(), "Invalid permissions");
    require(transaction.user0 == user0, "Invalid transaction");
    require(transaction.user1Status == Status.Deposited, "Withdraw not permitted");

    transactions[transactionKey].user1Status = Status.Withdrawn;

    // transaction not expired, user can withdraw ===========================
    if (block.timestamp <= transaction.expiresAt) {

      require(uint8(transaction.user0Status) >= uint8(Status.Deposited), "Other user must deposit");

      // custom fee or default fee ======
      uint256 feeToUse = defaultFee;
      string memory pairKey = _appendAddresses(transaction.token0, transaction.token1);
      if (pairs[pairKey].isExist == true) {
        feeToUse = pairs[pairKey].fee;
      }

      uint256 commissionAmount = transaction.token0Amount.mul(feeToUse).div(feeDivider);
      uint256 referCommission = commissionAmount.mul(referFee).div(feeDivider);

      // if there is a refer address, give them their cut
      if (transactions[transactionKey].refer != address(0) && referEnabled) {

        if (transaction.transactionType == TransactionType.ETHToToken) {
          payable(_msgSender()).transfer(transaction.token0Amount.sub(commissionAmount));
          payable(commissionAddress).transfer(commissionAmount.sub(referCommission));
          payable(transactions[transactionKey].refer).transfer(referCommission);
        }

        if (transaction.transactionType != TransactionType.ETHToToken) {
          IERC20(transaction.token0).safeTransfer(_msgSender(), transaction.token0Amount.sub(commissionAmount));
          IERC20(transaction.token0).safeTransfer(commissionAddress, commissionAmount.sub(referCommission));
          IERC20(transaction.token0).safeTransfer(transactions[transactionKey].refer, referCommission);
        }

      } else {

        if (transaction.transactionType == TransactionType.ETHToToken) {
          payable(_msgSender()).transfer(transaction.token0Amount.sub(commissionAmount));
          payable(commissionAddress).transfer(commissionAmount);
        }

        if (transaction.transactionType != TransactionType.ETHToToken) {
          IERC20(transaction.token0).safeTransfer(_msgSender(), transaction.token0Amount.sub(commissionAmount));
          IERC20(transaction.token0).safeTransfer(commissionAddress, commissionAmount);
        }
      }

      emit eventUserWithdraw(
        transactionId,
        transaction.user0,
        transaction.user1,
        transaction.token0,
        transaction.token0Amount.sub(commissionAmount),
        block.timestamp
      );
    }

    // expired: user can only get their original deposit back ===============
    if (block.timestamp > transaction.expiresAt) {

      if (transaction.transactionType == TransactionType.TokenToETH) {
        payable(_msgSender()).transfer(transaction.token1Amount);
      }

      if (transaction.transactionType != TransactionType.TokenToETH) {
        IERC20(transaction.token1).safeTransfer(_msgSender(), transaction.token1Amount);
      }

      emit eventUserWithdraw(
        transactionId,
        transaction.user0,
        transaction.user1,
        transaction.token1,
        transaction.token1Amount,
        block.timestamp
      );
    }
  }

  function getTransaction(bytes32 transactionId, address user0) public view returns (Transaction memory transaction) {
    string memory transactionKey = _returnTransactionKey(transactionId, user0);
    return transactions[transactionKey];
  }

  function _returnTransactionKey(bytes32 transactionId, address user0) internal pure returns (string memory) {
    return string(abi.encodePacked(transactionId, '||', user0));
  }
}

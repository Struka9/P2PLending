// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Verifier} from "./zokrates/verifier.sol";
import {IWorldID} from "@worldid/src/interfaces/IWorldID.sol";
import {ByteHasher} from "./ByteHasher.sol";

contract ZKoreLending is Ownable {
    using ByteHasher for bytes;
    using SafeERC20 for ERC20;

    struct Debt {
        address debtor;
        address creditor;
        uint256 amount;
        address token;
        uint256 timestamp;
    }

    // Errors
    error ZKoreLending__ZeroAddress();
    error ZKoreLending__EmptyArray();
    error ZKoreLending__NotValidToken();
    error ZKoreLending__NotEnoughBalance();
    error ZKoreLending__NotEnoughAllowance();
    error ZKoreLending__InvalidProof();
    error ZKoreLending__InvalidDebtId();

    // Events
    event Deposit(address indexed from, address indexed token, uint256 indexed amount);
    event Withdraw(address indexed from, address indexed token, uint256 indexed amount);
    event PreApprove(address from, address to, address token, uint256 amount);
    event Lend(address from, address to, address token, uint256 amount);
    event PaidDebt(address debtor, address creditor, uint256 debtId);

    // modifiers
    modifier onlyValidToken(address _token) {
        if (!tokenWhitelist[_token]) revert ZKoreLending__NotValidToken();
        _;
    }

    // Worldcoin params
    string constant APP_ID = "app_a176d00c9ad71e10da7ebd9664398c7a";
    string constant ACTION_NAME = "pro-sumer-human!";
    uint256 internal immutable EXTERNAL_NULLIFIER;
    // Only allow orb verified users
    uint256 internal constant GROUP_ID = 1;

    Verifier immutable zokratesVerifier;

    // Approved tokens to use
    mapping(address => bool) tokenWhitelist;

    // token => user => amount
    mapping(address => mapping(address => uint256)) tokenBalances;

    // approver => spender => token => amount
    mapping(address => mapping(address => mapping(address => uint256))) preApprovals;

    // Debtor => Debtee => Debts
    Debt[] debts;

    IWorldID immutable worldId;

    constructor(address _zokratesVerifier, address[] memory _tokenWhitelist, address _worldId) {
        if (_zokratesVerifier == address(0) || _worldId == address(0)) revert ZKoreLending__ZeroAddress();

        worldId = IWorldID(_worldId);
        zokratesVerifier = Verifier(_zokratesVerifier);

        EXTERNAL_NULLIFIER = abi.encodePacked(abi.encodePacked(APP_ID).hashToField(), ACTION_NAME).hashToField();

        uint256 length = _tokenWhitelist.length;
        if (length == 0) revert ZKoreLending__EmptyArray();

        for (uint256 i = 0; i < length;) {
            if (address(0) == _tokenWhitelist[i]) revert ZKoreLending__ZeroAddress();
            tokenWhitelist[_tokenWhitelist[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    function deposit(address _token, uint256 _amount) external onlyValidToken(_token) {
        // using safe transfer not need to check return value
        ERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        tokenBalances[_token][msg.sender] += _amount;
        // TODO: Stake it in some LP

        emit Deposit(msg.sender, _token, _amount);
    }

    function pay(uint256 _debtId, uint256 _amount) external {
        if (_debtId >= debts.length) {
            revert ZKoreLending__InvalidDebtId();
        }

        Debt memory debt = debts[_debtId];

        if (debt.debtor != msg.sender) {
            revert ZKoreLending__InvalidDebtId();
        }

        // No need to check return values
        ERC20(debt.token).safeTransferFrom(msg.sender, address(this), _amount);

        tokenBalances[debt.token][debt.creditor] += debt.amount;

        delete debts[_debtId];

        emit PaidDebt(debt.debtor, debt.creditor, _debtId);
    }

    function withdraw(address _token, uint256 _amount) external {
        tokenBalances[_token][msg.sender] -= _amount;
        // Using safeTransfer no need to check return value
        ERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _token, _amount);
    }

    function preApprove(address _token, uint256 _amount, address _spender) external onlyValidToken(_token) {
        preApprovals[msg.sender][_spender][_token] = _amount;

        emit PreApprove(msg.sender, _spender, _token, _amount);
    }

    function finalizeLoan(
        address _token,
        uint256 _amount,
        address _from,
        // Worldcoin Requirements
        address _signal,
        uint256 _root,
        uint256 _nullifierHash,
        uint256[8] calldata _proof,
        // ZKProof Requirements
        Verifier.Proof memory _zkProof,
        uint256[4] memory _input
    ) external returns (uint256 debtId) {
        // Check the allowance
        if (preApprovals[_from][msg.sender][_token] < _amount) {
            revert ZKoreLending__NotEnoughAllowance();
        }

        // Check the approver balance
        if (tokenBalances[_token][_from] < _amount) {
            revert ZKoreLending__NotEnoughBalance();
        }

        // WorldID verify
        worldId.verifyProof(_root, abi.encodePacked(_signal).hashToField(), _nullifierHash, EXTERNAL_NULLIFIER, _proof);

        // Check the verifier
        bool verified = zokratesVerifier.verifyTx(_zkProof, _input);

        if (!verified) {
            revert ZKoreLending__InvalidProof();
        }

        // Remove _from's liquidity
        tokenBalances[_token][_from] -= _amount;
        preApprovals[_from][msg.sender][_token] -= _amount;

        // using safeTransfer no need to check for return value
        ERC20(_token).safeTransfer(msg.sender, _amount);

        Debt memory debt =
            Debt({debtor: msg.sender, creditor: _from, token: _token, amount: _amount, timestamp: block.timestamp});

        debtId = debts.length;
        debts.push(debt);

        emit Lend(_from, msg.sender, _token, _amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Verifier} from "./zokrates/verifier.sol";

contract ZKoreLending is Ownable {
    using SafeERC20 for ERC20;

    struct Debt {
        address debtor;
        address creditor;
        uint256 amount;
        address token;
        uint256 started;
    }

    // Errors
    error ZKoreLending__ZeroAddress();
    error ZKoreLending__EmptyArray();
    error ZKoreLending__NotValidToken();
    error ZKoreLending__NotEnoughBalance();
    error ZKoreLending__NotEnoughAllowance();
    error ZKoreLending__InvalidProof();

    // Events
    event Deposit(address indexed from, address indexed token, uint256 indexed amount);
    event Withdraw(address indexed from, address indexed token, uint256 indexed amount);
    event PreApprove(address from, address to, address token, uint256 amount);
    event Lend(address from, address to, address token, uint256 amount);

    // modifiers
    modifier onlyValidToken(address _token) {
        if (!tokenWhitelist[_token]) revert ZKoreLending__NotValidToken();
        _;
    }

    // Only allow orb verified users
    uint256 internal constant GROUP_ID = 1;

    Verifier immutable verifer;

    // Approved tokens to use
    mapping(address => bool) tokenWhitelist;

    // token => user => amount
    mapping(address => mapping(address => uint256)) tokenBalances;

    // approver => spender => token => amount
    mapping(address => mapping(address => mapping(address => uint256))) preApprovals;

    // Debtor => Debtee => Debts
    Debt[] debts;

    constructor(address _verifier, address[] memory _tokenWhitelist) {
        if (_verifier == address(0)) revert ZKoreLending__ZeroAddress();

        verifer = Verifier(_verifier);

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
        // TODO: Receive tokens and cancel debt
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
        string calldata _appId,
        string calldata _actionId,
        bytes32 _nullifierHash,
        // ZKProof Requirements
        Verifier.Proof memory _proof,
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

        // TODO: Check the world coin contract

        // Check the verifier
        bool verified = verifer.verifyTx(_proof, _input);

        if (!verified) {
            revert ZKoreLending__InvalidProof();
        }

        // Remove _from's liquidity
        tokenBalances[_token][_from] -= _amount;
        preApprovals[_from][msg.sender][_token] -= _amount;

        // using safeTransfer no need to check for return value
        ERC20(_token).safeTransfer(msg.sender, _amount);

        Debt memory debt =
            Debt({debtor: msg.sender, creditor: _from, token: _token, amount: _amount, started: block.timestamp});

        debtId = debts.length;
        debts.push(debt);

        emit Lend(_from, msg.sender, _token, _amount);
    }
}

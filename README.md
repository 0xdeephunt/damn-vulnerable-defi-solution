# damn-vulnerable-defi-solution

This is a personal project dedicated to solving all the challenges in **[Damn Vulnerable DeFi (DVDF)](https://www.google.com/search?q=https://github.com/tinchoabbate/damn-vulnerable-defi)**. I've chosen **Foundry** as my primary development and testing framework to gain a deeper understanding of each vulnerability and to write efficient, native Solidity attack scripts.

## About this Project

[Damn Vulnerable DeFi](https://www.google.com/search?q=https://github.com/tinchoabbate/damn-vulnerable-defi), created by **[tinchoabbate](https://github.com/tinchoabbate)**, is an open-source educational platform. It features a series of smart contracts, each containing a specific, exploitable vulnerability.

By working through these challenges, I aim to practice and reinforce the following skills:

  * **Smart Contract Vulnerability Analysis**: Identifying and understanding common DeFi exploits like flash loan attacks, access control issues, reentrancy, and more.
  * **Foundry Testing Framework**: Becoming proficient with `forge` and `foundry` to write effective unit tests and exploit scripts in Solidity.
  * **EVM Debugging**: Using `forge`'s powerful debugging tools to trace and simulate transactions on a local EVM.
  * **DeFi Protocol Mechanics**: Gaining a hands-on understanding of the underlying principles of tokens, AMMs, and lending protocols.


## Solutions

Each challenge's solution is organized in its own directory, for example, `01-unstoppable/`. Inside, you'll find:

  * **The Challenge Contract**: The original, vulnerable contract file.
  * **The Test File**: My Foundry test script, which contains the exploit code.
  * **README.md** (Optional): A detailed breakdown of the vulnerability, my attack strategy, and a step-by-step explanation.

## How to Run the Solutions

1.  Clone this repository:

    ```bash
    git clone https://github.com/0xdeephunt/damn-vulnerable-defi-solution.git
    cd damn-vulnerable-defi-solution
    ```

    Optional
    ```bash
    git submodule update --init --recursive
    ```

2. Build Docker Image:

    ```bash
    docker build -t foundry-dev:latest .
    ```

3. Start the Service:

    ```bash
    docker run -it --rm --name foundry-env -v ".:/app" -p 8545:8545 -p 3000:3000 foundry-dev:latest 
    ```

4. Verify Foundry version

    ```
    # forge --version
    forge Version: 1.2.3-stable
    Commit SHA: a813a2cee7dd4926e7c56fd8a785b54f32e0d10f
    Build Timestamp: 2025-06-08T15:42:40.147013149Z (1749397360)
    Build Profile: maxperf
    ```

5.  Install & Build

    Install
    ```bash
    forge install
    ```

    Build
    ```bash
    forge clean
    forge build
    ```

6.  Run a solution

    ```bash
    forge test --mp test/<challenge-name>/<ChallengeName>.t.sol
    ```
    For example:
     ```bash
    forge test --mp test/unstoppable/Unstoppable.t.sol
    ```
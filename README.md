# VoxaLinkPro ICO & WrappedVoxaLinkPro Token

## Overview
This repository contains the smart contracts for the VoxaLinkPro Initial Coin Offering (ICO) and the WrappedVoxaLinkPro ERC20 token. The `VoxaLinkProICO` contract manages the ICO in different phases with distinct rates and bonuses, while the `WrappedVoxaLinkPro` contract is an ERC20 token where all tokens are initially assigned to the creator.

## Table of Contents
- [Setup and Installation](#setup-and-installation)
- [Using Remix IDE](#using-remix-ide)
- [Contract Details](#contract-details)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributions](#contributions)
- [License](#license)

## Setup and Installation
To use these contracts, you will need a Solidity development environment. Follow these steps to set up the project:

1. **Install Node.js and NPM:**
   - Ensure Node.js and npm (Node Package Manager) are installed. If not, download and install them from [Node.js website](https://nodejs.org/).

2. **Install Truffle:**
   - Truffle is a development framework for Ethereum. Install it globally via npm:
     ```
     npm install -g truffle
     ```

3. **Clone the Repository:**
   - Clone this repository to your local machine:
     ```
     git clone [repository_url]
     ```

4. **Install Dependencies:**
   - Navigate to the cloned directory and install the npm dependencies:
     ```
     npm install
     ```

5. **Configure Ethereum Client:**
   - Configure your Ethereum client (like Ganache) for deploying and testing the contracts.

## Using Remix IDE

Remix IDE is a powerful, open-source tool for Solidity development. Here's how to use it with our contracts:

1. **Access Remix IDE:**
   - Go to [Remix Ethereum IDE](https://remix.ethereum.org/).

2. **Create New Files:**
   - In the `File Explorers` tab, create a new single to have both contracts in a single file: `WrappedVoxaLinkPro.sol` and `VoxaLinkProICO.sol`, or create two new files to have both contracts in two different files. 

3. **Copy and Paste the Code:**
   - Copy the code from your local files and paste it into Remix.

4. **Compile the Contracts:**
   - Select the correct compiler version and click on `Compile`.

5. **Deploy the Contracts:**
   - Select the environment and click `Deploy`.

6. **Interact with the Contracts:**
   - Use the provided functions in the `Deployed Contracts` section.

7. **Import OpenZeppelin Contracts:**
   - Import them directly using `@openzeppelin` notation.

8. **Testing and Debugging:**
   - Use `Solidity Unit Testing` and `Debugger` tabs as needed.

## Contract Details

### WrappedVoxaLinkPro
- **Description:** ERC20 Token.
- **Constructor Parameters:** `owner`, `amount`.
- **Functions:** `burn(amount)`.

### VoxaLinkProICO
- **Description:** Manages the ICO.
- **Constructor Parameters:** `_wallet`, `_priceFeed`.
- **Key Functions:** `startICO()`, `buyTokens()`, `moveToNextPhase()`, and more.

## Testing
Run tests with Truffle:
- Truffle test

## Deployment
Deploy to an Ethereum network:
- truffle migrate --network [network_name]


## Contributions
Contributions are welcome. Please fork the repository and submit a pull request.

## License
This project is licensed under the MIT License.

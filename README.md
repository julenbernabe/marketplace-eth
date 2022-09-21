# The Marketplace Contract

This project contains all the files needed to deploy a Smart Contract for a Solidity-based Private Data Marketplace. Once you have installed this repository, refer to [the SCALE-MAMBA & Ethereum Client](https://github.com/julenbernabe/SMPC-BCK) in order to run the client for the marketplace.

## Installation

**Observation:** For this installation, you will need to have [Truffle](https://www.trufflesuite.com/docs/truffle/getting-started/installation) installed.

For a quick installation, run:

`truffle develop`

Then, simply run:

`migrate`

If it is your first time running these commands, you might get into trouble. If it is you case, firstly run

`migrate --to 2`

Then, refer to the file *subscribe.sol*, and change the token's contract address with the new one you obtained in the previous step. Once you do that, you can run

`migrate --from 3`

and you are done!

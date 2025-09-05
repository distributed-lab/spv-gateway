# ERC-8002: SPV Gateway 

Introduce a singleton contract for on-chain verification of transactions that happened on Bitcoin. The contract acts as a trustless Simplified Payment Verification (SPV) gateway where anyone can submit Bitcoin block headers. The gateway maintains the mainchain of blocks and allows the existence of Bitcoin transactions to be verified via Merkle proofs.

Link to [ERC-8002](https://ethereum-magicians.org/t/erc-8002-simplified-payment-verification-gateway/25038).

> [!NOTE]
> Since the ERC is currently a draft, there is no deployment on mainnet available. Please use [the contract on Sepolia](https://sepolia.etherscan.io/address/0xE8e6CA2113338c12eb397617371D92239f3E6A60) for testing purposes.

# How it Works

The gateway is a permissionless contract that operates by receiving raw Bitcoin block headers (anyone can submit them), which are then parsed and validated against Bitcoin's consensus rules:

1. Header Parsing: Raw 80-byte Bitcoin block headers are parsed into a structured *BlockHeader.HeaderData* format, handling Bitcoin's little-endian byte ordering.
2. Double SHA256 Hashing: Each block header is double SHA256 hashed to derive its unique block hash, which is then saved in a big-endian format.
3. Proof-of-Work Verification: The calculated block hash is checked against the current network difficulty target (derived from the *bits* field in the block header).
4. Chain Extension & Reorganization: New blocks are added to a data structure that allows for tracking multiple chains. When a new block extends a chain with larger cumulative work, the *mainchainHead* is updated, reflecting potential chain reorganizations.
5. Difficulty Adjustment: Every 2016 blocks, the contract calculates a new difficulty target based on the time taken to mine the preceding epoch. This ensures the 10-minute average block time is maintained.

Under the hood, the contract builds the mainchain but doesn't define its finality. The number of required block confirmations is up to the integration dApps to decide.

## Submitting Bitcoin Blocks

To submit a new Bitcoin block, call `addBlockHeader` function by passing a valid raw block header as a parameter. It is an open function that will revert in case Bitcoin PoW checks don't pass.

In case multiple blocks can be added, call `addBlockHeaderBatch` function to save ~15% on gas per block.

## Verifying Bitcoin Tx Inclusion

In order to verify the tx existence, the `checkTxInclusion` function needs to be called. 

The list parameters to be passed:

1. `merkleProof` - Merkle path for a given transaction to be checked. The Merkle path can either be built locally or by calling `gettxoutproof` on a Bitcoin node.
2. `blockHash` - Hash of the block to check the tx inclusion against. This block is required to exist in the SPV storage.
3. `txId` - Tx hash (Merkle leaf) to be checked.
4. `txIndex` - The Merkle "direction bits" to decide on left or right hashing order.
5. `minConfirmationsCount` - Number of required mainchain confirmation for the block to have.

> [!TIP]
> Please check out [this test case](./test/SPVContract.test.ts#L223) for more integration information.

## Permissionlessness

In order for the gateway to be truly permissionless, the contract's bootstrapping needs to be permissionless as well. We are working on a "proof-of-bitcoin" ZK proof to initialize the gateway in a trustless manner.

This will enable verification of historical Bitcoin transactions otherwise too expensive to include. Syncing up the gateway from Bitcoin's genesis would cost ~100 ETH on the mainnet.

# Disclaimer

Bitcoin + Ethereum = <3

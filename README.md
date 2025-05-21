# SPV Contracts

Smart contract for verifying Bitcoin block headers on EVM-compatible chains using the **Simple Payment Verification (SPV)** method.

This contract behaves like an SPV node: it builds a valid chain of Bitcoin block headers, verifies them according to Bitcoin consensus rules, and enables Merkle Proof-based verification of Bitcoin transactions.

## Features

- Stores and verifies Bitcoin block headers
- Validates headers using:
  - Proof of Work (`bits` → `target`)
  - Median time rule
  - Chain continuity
- Handles difficulty adjustment every 2016 blocks
- Supports pending difficulty epochs before finalization
- Stores historical targets and supports reorg handling

## Contract: `SPVContract.sol`

### Key Functions

#### `addBlockHeader(bytes calldata blockHeaderRaw)`
Adds and validates a new block header, updates internal state, and emits an event.

### Validation Rules
- `prevBlockHash` must point to a known block
- New `blockHash` must not exist
- Header `bits` must match the expected network target
- Header `time` must be > median of last 11 blocks
- `blockHash` must be less than or equal to the target (valid PoW)

## Storage Structure

- `BlocksData` – stores block headers, timestamps, and chain height
- `TargetsData` – handles target values and difficulty epochs
- `pendingTargetHeightCount` – controls target finalization after N blocks

## Dev Info
### Compilation

To compile the contracts, use the next script:

```bash
npm run compile
```

### Test

To run the tests, execute the following command:

```bash
npm run test
```

Or to see the coverage, run:

```bash
npm run coverage
```

### Local deployment

To deploy the contracts locally, run the following commands (in the different terminals):

```bash
npm run private-network
npm run deploy-localhost
```

### Bindings

The command to generate the bindings is as follows:

```bash
npm run generate-types
```
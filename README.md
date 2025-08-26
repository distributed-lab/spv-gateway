# 🛡️ SPV Gateway: Bitcoin Light Client on EVM
Welcome to the **SPV Gateway**, a robust and efficient Solidity implementation for verifying Bitcoin block headers directly on an EVM-compatible blockchain. This contract empowers dApps to act as a **Simplified Payment Verification (SPV)** client, allowing them to validate the existence and inclusion of Bitcoin transactions without needing to run a full Bitcoin node.

# ✨ Why this SPV Gateway?
In the decentralized world, connecting different blockchain ecosystems securely is paramount. This SPV Gateway provides a trust-minimized bridge, enabling smart contracts on EVM chains to cryptographically verify the state of the Bitcoin blockchain. This opens doors for exciting use cases like:
- **Cross-chain bridges** for Bitcoin-backed assets
- **Light clients** for dApps that need to confirm Bitcoin transaction finality
- **Decentralized custodianship** solutions
- **Oracle services** for Bitcoin data on EVM

# 🚀 Key Features
- **Block Header Submission:** Efficiently add individual or batches of Bitcoin block headers to the contract.
- **Mainchain Tracking:** Automatically identifies and updates the "main" Bitcoin chain based on accumulated work.
- **Block Validation:** Verifies block headers against Bitcoin's consensus rules, including:
  - Proof-of-Work (target difficulty)
  - Block time validity (median time past)
  - Chain continuity (previous block hash)
- **Block Information Retrieval:** Query detailed information about any stored block, such as:
  - Its Merkle root
  - Its height
  - Its inclusion status in the mainchain
  - Its cumulative work (difficulty)
  - Its confirmation count relative to the mainchain head
- **Difficulty Adjustment:** Integrates Bitcoin's precise difficulty adjustment algorithm to accurately calculate current and future targets.

# ⚙️ How it Works (Under the Hood)
The contract operates by receiving raw Bitcoin block headers, which are then parsed and validated against Bitcoin's strict consensus rules.

1. **Header Parsing:** Raw 80-byte Bitcoin block headers are parsed into a structured *BlockHeader.HeaderData* format. This involves handling Bitcoin's unique little-endian byte ordering.
2. **Double SHA256 Hashing:** Each block header is double SHA256 hashed to derive its unique block hash, which is then byte-reversed for standard representation.
3. **Proof-of-Work Verification:** The calculated block hash is checked against the current network difficulty target (derived from the *bits* field in the header).
4. **Chain Extension & Reorganization:** New blocks are added to a data structure that allows for tracking multiple chains. When a new block extends a chain with higher cumulative work, the *mainchainHead* is updated, reflecting potential chain reorganizations.
5. **Difficulty Adjustment:** Every 2016 blocks, the contract calculates a new difficulty target based on the time taken to mine the preceding epoch. This ensures the 10-minute average block time is maintained.

# 📊 Flow Diagrams
These diagrams outline the step-by-step process for adding block headers to the SPV Gateway.

### `addBlockHeader(bytes calldata blockHeaderRaw_)` Sequence Diagram

```mermaid
sequenceDiagram
  participant Caller
  participant SPVGateway
  participant BlockHeaderLib
  participant TargetsHelperLib

  Caller->>SPVGateway: addBlockHeader(blockHeaderRaw)
  activate SPVGateway

  SPVGateway->>BlockHeaderLib: 1. Parse blockHeaderRaw_ (parseBlockHeaderData)
  activate BlockHeaderLib
  BlockHeaderLib-->>SPVGateway: 1.1. Check length (80 bytes) & LE to BE
  alt Length Invalid
      BlockHeaderLib--xSPVGateway: Error: InvalidBlockHeaderDataLength
      SPVGateway--xCaller: Revert
  end
  BlockHeaderLib-->>SPVGateway: 1.2. Return BlockHeaderData & blockHash
  deactivate BlockHeaderLib

  SPVGateway->>SPVGateway: 1.3. Check blockHash existence
  alt BlockHash Exists
      SPVGateway--xCaller: Error: BlockAlreadyExists
  end

  SPVGateway->>SPVGateway: 2. Check prevBlockHash existence
  alt Prev Block Missing
      SPVGateway--xCaller: Error: PrevBlockDoesNotExist
  end

  SPVGateway->>SPVGateway: 3. Calculate newBlockHeight = prevBlockHeight + 1

  SPVGateway->>SPVGateway: 4. Get Current Target
  SPVGateway->>SPVGateway: 4.1. Get target from prevBlockBits
  SPVGateway->>TargetsHelperLib: Check if newBlockHeight is Recalculation Block (isTargetAdjustmentBlock)
  activate TargetsHelperLib
  alt Recalculation Block
      SPVGateway->>SPVGateway: Recalculate target & Save lastEpochCumulativeWork
      TargetsHelperLib-->>SPVGateway: Return newNetworkTarget
  else Not Recalculation Block
      TargetsHelperLib-->>SPVGateway: Use prevBlockTarget as networkTarget
  end
  deactivate TargetsHelperLib

  SPVGateway->>SPVGateway: 5. Check Block Rules
  SPVGateway->>TargetsHelperLib: 5.1. Check Header Target == Contract Target
  activate TargetsHelperLib
  TargetsHelperLib-->>SPVGateway: Result
  deactivate TargetsHelperLib
  alt Invalid Target
      SPVGateway--xCaller: Error: InvalidTarget
  end

  SPVGateway->>SPVGateway: 5.2. Check newBlockHash <= networkTarget (PoW)
  alt Invalid Block Hash
      SPVGateway--xCaller: Error: InvalidBlockHash
  end

  SPVGateway->>SPVGateway: 5.3. Check newBlockTime >= medianTime
  alt Invalid Block Time
      SPVGateway--xCaller: Error: InvalidBlockTime
  end

  SPVGateway->>SPVGateway: 6. Add Block To Chain
  SPVGateway->>SPVGateway: 6.1. Save newBlockHeader & newBlockHash to Storage

  SPVGateway->>SPVGateway: 6.2. Update Mainchain
  alt 6.2.1. prevBlockHash == mainchainHead?
      SPVGateway->>SPVGateway: Move mainchainHead to newBlockHash
  else
      SPVGateway->>SPVGateway: 6.2.2. Calculate New Block & Current Head Cumulative Work
      SPVGateway->>SPVGateway: 6.2.3. newBlock Cumulative Work > Current Head?
      alt New Block Has Higher Work
          SPVGateway->>SPVGateway: Set New Block as mainchainHead
          SPVGateway->>SPVGateway: Recursively update mainchain path backwards (do-while loop)
      end
  end

  SPVGateway->>SPVGateway: Emit BlockHeaderAdded
  SPVGateway-->>Caller: Transaction Complete
  deactivate SPVGateway
```

### `addBlockHeaderBatch(bytes[] calldata blockHeaderRawArr_)` Sequence Diagram

This function processes multiple block headers in a single transaction, iterating through the array and validating each sequentially.

```mermaid
sequenceDiagram
  participant Caller
  participant SPVGateway
  participant BlockHeaderLib
  participant TargetsHelperLib

  Caller->>SPVGateway: addBlockHeaderBatch(blockHeaderRawArray_)
  activate SPVGateway

  SPVGateway->>SPVGateway: Check if Header Array is Empty
  alt Array Empty
      SPVGateway--xCaller: Error: EmptyBlockHeaderArray
  end

  SPVGateway->>BlockHeaderLib: 1. Parse Block Headers Array (_parseBlockHeadersRaw)
  activate BlockHeaderLib
  BlockHeaderLib-->>SPVGateway: Returns BlockHeaderData[] & bytes32[]
  deactivate BlockHeaderLib

  loop For each blockHeader in parsed array (from i=0 to length-1)
      SPVGateway->>SPVGateway: 2. Check prevBlockHash for current block
      alt First block in batch
          SPVGateway->>SPVGateway: Check prevBlockHash existence (like addBlockHeader)
          alt Prev Block Missing
              SPVGateway--xCaller: Error: PrevBlockDoesNotExist
          end
      else Subsequent blocks
          SPVGateway->>SPVGateway: Check prevBlockHash == blockHash of (i-1)th block
          alt Order Invalid
              SPVGateway--xCaller: Error: InvalidBlockHeadersOrder
          end
      end

      SPVGateway->>SPVGateway: 3. Calculate currentBlockHeight = prevBlockHeight + 1

      SPVGateway->>SPVGateway: 4. Get Current Target (like addBlockHeader)
      SPVGateway->>TargetsHelperLib: Check for Recalculation Block & Recalculate if needed
      activate TargetsHelperLib
      TargetsHelperLib-->>SPVGateway: Return networkTarget
      deactivate TargetsHelperLib

      SPVGateway->>SPVGateway: 5. Get Median Time
      alt 5.1. Num blocks added < 12
          SPVGateway->>SPVGateway: Use _getStorageMedianTime (like addBlockHeader)
      else 5.2. Num blocks added >= 12
          SPVGateway->>SPVGateway: Use _getMemoryMedianTime (from batch data)
      end

      SPVGateway->>SPVGateway: 6. Validate Block Rules (_validateBlockRules)
      alt Validation Fails
          SPVGateway--xCaller: Error: InvalidTarget / InvalidBlockHash / InvalidBlockTime
      end

      SPVGateway->>SPVGateway: 7. Add Block To Chain (_addBlock)
      SPVGateway->>SPVGateway: Emit BlockHeaderAdded
  end

  SPVGateway-->>Caller: Transaction Complete
  deactivate SPVGateway
```


# 📦 Contract Components
The solution primarily consists of the main SPV Gateway contract and the TargetsHelper library, which manages difficulty adjustments.

## SPVGateway
This is the central contract that users will interact with. It serves as the primary interface for managing Bitcoin block headers on the EVM. It handles the core logic for adding and validating blocks, tracking the main Bitcoin chain, and providing querying functionalities. All custom errors and events related to the SPV operations are defined here, ensuring clear feedback and transparency during contract execution.

## TargetsHelper Library
This library encapsulates all the complex mathematical and logical operations related to Bitcoin's difficulty targets. It provides functions to accurately calculate new difficulty targets based on elapsed time between blocks, ensuring the contract adheres to Bitcoin's dynamic difficulty adjustment rules. Additionally, it offers utilities for converting between the compact "bits" format (as found in Bitcoin block headers) and the full 256-bit target value, and it calculates the cumulative work associated with a given block or epoch, which is vital for determining the most valid chain.

# 💻 Dev Info
## Compilation
To compile the contracts, use the next script:

```bash
npm run compile
```

## Test
To run the tests, execute the following command:

```bash
npm run test
```

Or to see the coverage, run:

```bash
npm run coverage
```

## Local deployment
To deploy the contracts locally, run the following commands (in the different terminals):

```bash
npm run private-network
npm run deploy-localhost
```

## Bindings
The command to generate the bindings is as follows:

```bash
npm run generate-types
```

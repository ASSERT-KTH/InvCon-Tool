# InvCon — Invariant Mining Results

This directory contains the invariant files (`.inv`) produced by running [InvCon](https://github.com/ASSERT-KTH/InvCon-Tool) against a curated dataset of real-world vulnerable Ethereum smart contracts.

---

## Directory Structure

Each subdirectory corresponds to one contract run and is named after the incident identifier from the dfhl-invariants database:

```
results/
├── 201804_BEC/
│   ├── <contract_address>.inv       # Daikon invariant file
├── 201804_SmartMesh/
│   └── ...
├── 202102_Yearn_ydai/
│   └── ...
└── ...
```

---

## How These Results Were Generated

### Environment

All runs were performed inside a Docker container built from the `Dockerfile` at the root of this repository. The image is based on `ubuntu:22.04` and pins the following key dependencies:

| Dependency | Version |
|---|---|
| Python | 3.10 (system) |
| Slither | 0.10.0 |
| Daikon | 5.8.6 |
| Node.js | system (apt) |
| web3.py | bundled with Slither |

### Running a Single Contract

```bash
# Build the image
docker build -t invcon .

# Run against a contract address
docker run --rm \
  -e ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY \
  -v $(pwd)/results/<incident_name>:/home/realworldcontracts/ \
  invcon \
  --eth_address <0x_contract_address> \
  --workspace /home/realworldcontracts/
```

The `ETHERSCAN_API_KEY` environment variable must be set to a valid [Etherscan V2 API key](https://docs.etherscan.io/getting-started/viewing-api-usage-statistics). The tool fetches source code, ABI, and transaction histories live from Etherscan.

### Running the Full Batch

The full batch was executed using the following script on a WSL (Ubuntu) host:

```bash
#!/bin/bash
mkdir -p ~/invcon-results

# Parse contract addresses from the dfhl-invariants database JSON
python3 -c "
import json
db = json.load(open('database.json'))
for name, entry in db.items():
    if entry.get('blockchain') == 'Ethereum' and entry.get('vulnerable_contract_address'):
        print(f\"{name},{entry['vulnerable_contract_address']}\")
" > /tmp/contracts.csv

while IFS=, read -r name address; do
    echo "=== Running $name ($address) ==="
    mkdir -p ~/invcon-results/$name
    docker run --rm \
        -e ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY \
        -v ~/invcon-results/$name:/home/realworldcontracts/ \
        invcon \
        --eth_address "$address" \
        --workspace /home/realworldcontracts/ \
        > ~/invcon-results/$name/run.log 2>&1 || true
    echo "Done."
done < /tmp/contracts.csv
```

### Committing Results to This Repository

Results were pushed to this repository as follows:

```bash
# From the repo root (after running the batch)
cp -r ~/invcon-results/* results/

# Stage and commit
git add results/
git commit -m "feat(results): add InvCon invariant mining output for dfhl-invariants dataset

- 26 contracts attempted from the ASSERT-KTH dfhl-invariants database
- 12 clean successful runs, 3 partial (no Daikon samples), 9 hard failures
- See results/README.md for full execution outcome table and root cause analysis"

git push origin main
```

---

## Execution Outcomes

| Incident ID | Contract | Status | `.inv` File | Notes |
|---|---|:---:|:---:|---|
| 201804_BEC | `0xC5d...` | ✅ | `BecToken.inv` | ERC20 token; fallback IndexErrors non-fatal |
| 201804_SmartMesh | `0x55f...` | ✅ | `SMT.inv` | ERC20 token; 3000 txs in ~18 min |
| 202008_Opyn | `0x951...` | ❌ | — | `Web3.soliditySha3` deprecated API crash |
| 202102_Yearn_ydai | `0xACd...` | ✅ | `yVault.inv` | Vault contract; 2000 txs |
| 202109_Nimbus | `0xc0A...` | ❌ | — | `uint112` not supported in storage layout parser |
| 202201_Anyswap | `0x6b7...` | ✅ | `AnyswapV4Router.inv` | Cross-chain router; 3000 txs |
| 202202_TecraSpace | `0x...` | ❌ | — | Crawler `SystemExit(-1)` — Etherscan data unavailable |
| 202206_InverseFinance | `0xE8b...` | ⚠️ | `YVCrv3CryptoFeed.inv` (empty) | 0 transactions crawled — likely proxy contract |
| 202209_BadGuysbyRPF | `0xB84...` | ❌ | — | Unsupported NFT parameter types (URI strings, bytes) |
| 202210_N00d | `0x356...` | ✅ | `SushiBar.inv` | 97 txs; clean run |
| 202210_Uerii | `0x418...` | ✅ | `Token.inv` | 491 txs; clean run |
| 202212_JAY | `0xf29...` | ⚠️ | `JAY.inv` (partial) | Malformed dtrace at line 5520 (string escaping) |
| 202301_QTN | `0xC9f...` | ✅ | `QUATERNION.inv` | 387 txs; clean run |
| 202305_ERC20TokenBank | `0x765...` | ⚠️ | `ExchangeBetweenPools.inv` (empty) | 0 tx — proxy/router pattern |
| 202306_VINU | `0xF7e...` | ✅ | `VINU.in` | 14 txs; clean run |
| 202308_Uwerx | `0x430...` | ✅ | `Uwerx.inv` | 75 txs; clean run |
| 202309_uniclyNFT | `0xd3c...` | ❌ | — | `bytes4` not supported in storage layout parser |
| 202310_PseudoETH | `0x203...` | ❌ | — | `uint112` not supported (Uniswap V2 pattern) |
| 202311_grok | `0x839...` | ✅ | `GROK.inv` | 3000 txs; ~35 min crawl |
| 202404_HoppyFrogERC | `0xe5c...` | ✅ | `Hoppy.inv` | ERC721; 2000 txs; non-fatal NFT param errors |
| 202406_APEMAGA | `0x56f...` | ✅ | `Tonken.inv` | 20 txs; clean run |
| 202406_JokInTheBox | `0xA64...` | ❌ | — | Source is Handlebars template `{{` — Slither compile fail |
| 202406_WIFCOIN_ETH | `0xA1c...` | ❌ | — | Same `{{` template source issue |
| 202408_OMPxContract | `0x203...` | ❌ | — | `Unknown Error` in `Contract.__init__` |
| 202409_Bedrock_DeFi | `0x702...` | ✅ | `Vault.inv` | 2 txs; clean run |
| 202409_OnyxDAO | `0x...` | ❌ | — | `Unknown Error` in `Contract.__init__` |

**Legend:** ✅ Full success — `.inv` file produced with Daikon output · ⚠️ Tool completed but no usable invariants · ❌ Hard failure — no output produced

---

## Limitations

1. **Transaction cap:** InvCon fetches at most 2,000 transactions per contract (configurable via `--txs_limit`). 
2. **Etherscan dependency:** Results require a live Etherscan connection. API rate limits may cause partial crawls. T
3. **Unsupported Solidity types:** InvCon's storage layout parser (`parsing/storageLayout.py`) does not handle sub-32-byte integer types (`uint112`, `uint96`, etc.) or fixed-size byte arrays (`bytes4`, `bytes8`). Contracts using these types (e.g., Uniswap V2 forks using `uint112` for reserves) will fail.
4. **Proxy contracts:** InvCon queries only the specified address. Proxy contracts that delegate all logic to an implementation contract will return 0 transactions and produce empty invariant files.
5. **No ERC721 support:** NFT-specific parameter types (`tokenId` + `bytes data` in `safeTransferFrom`) cause non-fatal decoding errors. Some invariants may be absent for ERC721 contracts.


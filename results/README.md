# InvCon Reproducibility Study

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
---
## References

- Original repository: https://github.com/Franklinliu/InvCon-Tool 
- Fork:  https://github.com/ASSERT-KTH/InvCon-Tool
- Paper: "InvCon: A Dynamic Invariant Detector for Ethereum Smart Contract"


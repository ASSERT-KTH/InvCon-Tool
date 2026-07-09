# InvCon ↔ Ground Truth comparison via Sindi

Pipeline to compare the invariants produced by **InvCon** (in Daikon format)
against the **ground truth** extracted from the patches (`diff.diff`), using
the semantic differencing engine **Sindi**.

The semantic comparison is delegated **100% to Sindi**, the only
additional work is the *pre-processing* needed to make the input compatible
(translating InvCon's Daikon dialect, extracting the predicates from the diffs).

---

## Components

| File | Role |
|------|------|
| `extract_gt_from_diffs.py` | Extracts the ground truth from the `diff.diff` files → `ground_truth.csv` |
| `daikon_preprocessor.py` | Translates InvCon's Daikon invariants into Sindi-compatible predicates |
| `compare_invcon_sindi.py` | Compares each InvCon invariant against the ground truth via Sindi → CSV |
| `test_daikon_preprocessor.py` | Tests for the preprocessor's translation rules |

---

## Requirements

- Python 3.8+
- Sindi installed:

```bash
pip install Sindi
```

---

## Execution (two steps)

### Step 1 — Extract the ground truth from the diffs

```bash
python3 extract_gt_from_diffs.py --diffs-dir ./diffs --out ./ground_truth.csv
```

Reads the **added** lines (`+`) of each `diff.diff`, reconstructs the
`require`/`assert` statements (including multi-line ones), extracts the **bare
predicate** (removing `require(`, `;`, error messages and comments) and splits
`&&` clauses into atomic predicates.


### Step 2 — Compare with Sindi

```bash
python3 compare_invcon_sindi.py \\
    --daikon-dir ./daikon \\
    --ground-truth ./ground_truth.csv \\
    --out ./verdicts.csv
```

For each contract it looks for the Daikon file in `daikon/<contract>/*.inv`,
translates each invariant with `daikon_preprocessor`, and compares it against
the ground-truth predicate through Sindi.

Produces two files:

- `verdicts.csv` — one row per compared InvCon invariant (detail)
- `verdicts_summary.csv` — one verdict per `(contract, function)` pair

---

## Output: `verdicts_summary.csv`

Contains one row per `(contract, function)` pair with Sindi's textual verdict.

| Column | Meaning |
|--------|---------|
| `contract` | Contract name |
| `function` | Function the ground truth refers to |
| `gt_predicate` | The ground-truth predicate extracted from the diff |
| `n_invariant_lines` | Number of InvCon invariants examined for that comparison |
| `verdict_raw` | Verdict (see below) |

Possible values of `verdict_raw`:

Sindi's four official strings (when a comparison actually took place):

- `The predicates are equivalent.` — the InvCon invariant is equivalent to the ground truth
- `The first predicate is stronger.` — the InvCon invariant is stronger
- `The second predicate is stronger.` — the ground truth is stronger
- `The predicates are not equivalent and neither is stronger.` — no relationship

Plus two pipeline labels (when no Sindi comparison was possible):

- `no invariant for the vulnerable function` — InvCon produced no invariant for
  that function (`n_invariant_lines = 0`), so there is nothing to compare against
  the ground truth.
- `no comparable invariant (all non-relational)` — InvCon produced invariants,
  but all of them are non-relational (meta-statements such as `has only one
  value`, or array/aggregate syntax such as `sum(...)` / `[]`), none of which is
  a boolean predicate Sindi can compare.

---

## Output: `verdicts.csv` (detail)

One row per compared InvCon invariant, with:

| Column | Meaning |
|--------|---------|
| `contract`, `function`, `ppt` | Contract, function and Daikon program point |
| `gt_predicate` | Ground-truth predicate |
| `invcon_raw` | Original InvCon invariant (Daikon format) |
| `invcon_sanitized` | Invariant after the Daikon→Sindi translation |
| `verdict_raw` | Sindi verdict (or a note, if not comparable) |
| `category` | Synthetic category (see below) |

Categories in `category`:

- `exact_or_equiv`, `invcon_stronger`, `gt_stronger`, `none` — outcomes of the
  Sindi comparison
- `meta` — Daikon meta-statement (`has only one value`, `!= null`): not a
  boolean predicate
- `object_id` — object identity (`this == orig(this)`)
- `unmappable` — Daikon syntax recognized as non-translatable: aggregates
  (`sum(...)`) and array/accessor syntax (`[]`, `[].getValue()`,
  `[].getSubLength()`), plus `one of {...}`, `size(...)`, `getValueOfKey(...)`
- `unknown` / `error` — non-classifiable row / comparison error

---

## The Daikon→Sindi preprocessor

InvCon's invariants are in a **Daikon dialect**. Most lines are already
accepted by Sindi's tokenizer; only the array/accessor syntax breaks it.
`daikon_preprocessor.py`:

- **leaves relational predicates untouched** where possible — `orig(x)`, dotted
  names, `== false`, numeric literals are all accepted by Sindi as-is (variable
  names stay *mangled*, for fidelity to the original tool)
- **filters out** meta-statements (`has only one value`, `!= null`) and object
  identity (`this == orig(this)`) — not boolean predicates
- **flags as `unmappable`** (skipped, not translated) any line containing an
  aggregate `sum(...)` or array/accessor syntax (`[]`, `[].getValue()`, …). These
  are **not** rewritten into opaque symbols: `X[]` and `X_`, or `sum(...)` and
  `sum_...`, are not the same thing, so inventing a symbol would create a
  spurious correspondence. Marking them `unmappable` keeps the distinction
  between "non-comparable construct" and a real negative comparison, and matches
  the InvCon+ pipeline's handling of the analogous `Sum(...)` syntax.

`orig(x)` is **not** touched: Sindi already accepts it as a symbol.

The shared ground-truth loader also normalises numeric literals that Sindi's
tokenizer cannot handle: underscore digit separators (`10_000` → `10000`) and
constant power expressions (`10000**2` → `100000000`).

### Preprocessor tests

```bash
python3 test_daikon_preprocessor.py
```

Checks both the classification/translation of each known construct, and that
every relational output is actually parsable by Sindi. Expected result:

```
[PASS] classification_and_mapping
[PASS] relational_outputs_parse_in_sindi
2/2 tests passed.
```

---

## Results

Comparison outcome for the evaluated contracts. Each verdict is the strongest
one obtained by Sindi across all InvCon invariants for that
`(contract, function)`, or a pipeline label when no comparison was possible.

| Contract | Function | Ground-truth predicate | Number of InvCon Invariants | Verdict (Sindi) |
|---|---|---|---|---|
| 201804_BEC | batchTransfer | `_value <= uint256(-1) / cnt` | 63 | The predicates are not equivalent and neither is stronger. |
| 201804_SmartMesh | transferProxy | `total >= _feeSmt` | 112 | The predicates are not equivalent and neither is stronger. |
| 201804_SmartMesh | transferProxy | `total >= _value` | 112 | The predicates are not equivalent and neither is stronger. |
| 202102_Yearn_ydai | earn | `msg.sender == governance` | 75 | The predicates are not equivalent and neither is stronger. |
| 202202_Anyswap | anySwapOutUnderlyingWithPermit | `v == 27 \|\| v == 28` | 45 | The predicates are not equivalent and neither is stronger. |
| 202206_InverseFinance | latestAnswer | `crvLPTokenPrice >= lower` | 0 | no invariant for the vulnerable function |
| 202206_InverseFinance | latestAnswer | `crvLPTokenPrice <= upper` | 0 | no invariant for the vulnerable function |
| 202210_N00d | enter | `!__lock_modifier0_lock` | 61 | The predicates are not equivalent and neither is stronger. |
| 202210_Uerii | mint | `totalSupply() + amount <= CAP` | 33 | The predicates are not equivalent and neither is stronger. |
| 202212_JAY | buyJay | `!__lock_modifier0_lock` | 0 | no invariant for the vulnerable function |
| 202301_QTN | transfer | `msg.sender == address(uniswapV2Router)` | 296 | The predicates are not equivalent and neither is stronger. |
| 202305_ERC20TokenBank | doExchange | `namount >= (camount * 995) / 1000` | 0 | no invariant for the vulnerable function |
| 202306_VINU | addLiquidityETH | `size == 0` | 23 | The predicates are not equivalent and neither is stronger. |
| 202308_Uwerx | transfer | `uniswapPoolAddress!=address(0x1)` | 55 | The predicates are not equivalent and neither is stronger. |
| 202308_Uwerx | transfer | `_balances[to]==(toBalance - userTransferAmount)` | 55 | The second predicate is stronger. |
| 202311_grok | _transfer | `swapAmount <= taxAmount` | 633 | The predicates are not equivalent and neither is stronger. |
| 202404_HoppyFrogERC | _transfer | `swapAmount <= maxSwapForSell` | 762 | The predicates are not equivalent and neither is stronger. |
| 202406_APEMAGA | family | `msg.sender == account` | 83 | The predicates are not equivalent and neither is stronger. |
| 202409_Bedrock_DeFi | mint | `uniBTCAmount * 1e10 < msg.value` | 42 | The predicates are not equivalent and neither is stronger. |

| Verdict | Count |
|---|---|
| The predicates are not equivalent and neither is stronger. | 14 |
| The second predicate is stronger. | 1 |
| no invariant for the vulnerable function | 4 |

### Reading the results

- **14** predicates → `not equivalent / neither stronger`: InvCon produced
  invariants for the vulnerable function, but none of them matches (or implies,
  or is implied by) the patch's security guard.
- **4** predicates → `no invariant for the vulnerable function`.
- **1** predicate → `second predicate is stronger` (`202308_Uwerx`): the ground
  truth is stronger than the InvCon invariant, i.e. InvCon inferred only a
  weaker property than the one the patch enforces.

Across the whole dataset, InvCon never produced an invariant equivalent to or
stronger than a patch-derived security guard. Note that some contracts generate
a very high number of invariants (e.g. `202404_HoppyFrogERC`: 762,
`202311_grok`: 633), yet this volume does not translate into capturing the
security-relevant property.

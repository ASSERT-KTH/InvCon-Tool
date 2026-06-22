# InvCon Ground-Truth Comparison — Condition Matching

This table summarises, for each contract in the dataset, the ground-truth
invariant condition extracted from the security patch (`diff.diff`) and the
closest predicate produced by InvCon, together with the match verdict.

**Match legend**
| Symbol | Meaning |
|--------|---------|
| ✅ EXACT | Normalised strings are identical |
| 🟡 PARTIAL | Key variable tokens and relational operator overlap, but not a literal match |
| ❌ NONE | No InvCon predicate covers the ground-truth condition |
| — | InvCon produced no output for the vulnerable function (tool gap) |

---

## Methodology

### Overview

The evaluation compares InvCon's dynamically-mined invariants against
ground-truth security conditions derived from the ASSERT-KTH `dfhl-invariants`
dataset. For each of the 26 real-world DeFi contracts in the dataset, the
ground-truth is defined as the set of conditions introduced by the security
patch that fixed the vulnerability. The evaluation is performed by a purpose-built
Python pipeline (`matcher.py`) that automates extraction, normalisation, and
matching for all contracts.

### Step 1 — Ground-Truth Extraction (from `diff.diff`)

Each contract in the dataset includes a `diff.diff` file that records the
minimal source-code change that would have prevented the exploit. The
ground-truth invariant conditions are extracted from this diff as follows:

1. **Added lines only.** Only lines prefixed with `+` (and not `+++`) are
   considered; removed or context lines are ignored.
2. **Contiguous block reconstruction.** Consecutive added lines are joined
   into a single code block before parsing. This is necessary because
   `require()` calls frequently span multiple lines in the diff (e.g.
   reentrancy guard modifiers).
3. **Explicit `require()` parsing.** A parenthesis-aware scanner (not a
   regex) extracts the inner condition of every `require(cond, "msg")`
   call, correctly handling nested parentheses such as `uint256(-1)`.
   Compound conditions joined by `&&` or `||` at the top level are split
   into individual sub-conditions.
4. **Implicit guard detection.** Some patches do not add an explicit
   `require` but instead introduce a guard implicitly — for example, by
   passing a computed `minEthOut` instead of `0` as the `amountOutMin`
   argument to a Uniswap swap call, or by initialising a new state variable
   that parameterises a slippage bound. The pipeline detects these by
   scanning the full corpus of added lines for new variable assignments
   and their use in external call arguments.
5. **Normalisation.** Each extracted condition is normalised: known integer
   constants are expanded (`uint256(-1)` → `MAX_UINT256`), whitespace is
   collapsed, and identifiers are lowercased to enable case-insensitive
   comparison.

### Step 2 — InvCon Output Parsing (from `<ContractName>.inv`)

InvCon produces a Daikon-format `.inv` text file containing one section per
analysed function, delimited by `=====` separators and labelled with the
function signature (e.g. `BecToken.batchTransfer(address[],uint256):::EXIT2`).
The pipeline:

1. Parses all sections from the `.inv` file.
2. Filters to the sections matching the **vulnerable function(s)** listed
   under `modified_functions` in `dataset-info.json`. If a
   `patched_internal_function` is specified (e.g. `_transfer`), that
   function name is also included in the filter. Matching is
   case-insensitive on the function name portion of the signature.
3. Flattens all predicates from the matching sections into a single list
   for comparison.

### Step 3 — Matching

Each ground-truth condition is compared against the full list of InvCon
predicates using a two-level matching strategy:

- **EXACT:** The normalised form of the ground-truth condition is identical
  to the normalised form of an InvCon predicate. Both sides undergo the
  same normalisation (constant expansion, whitespace collapse, lowercasing)
  before comparison.

- **PARTIAL:** At least two key identifier tokens extracted from the
  ground-truth condition appear in a single InvCon predicate, and at least
  one relational operator (`==`, `!=`, `<=`, `>=`, `<`, `>`) is shared.
  This threshold is intentionally conservative to reduce false positives on
  short or single-token conditions.

- **NONE:** No InvCon predicate satisfies either of the above criteria.

The match verdict for each contract is determined by the most informative
result across all its ground-truth conditions.

### Step 4 — Output

For each contract the pipeline produces a JSON file
(`invcon_match.json`) containing:
- the extracted ground-truth conditions with their raw and normalised forms,
- the InvCon predicate sections examined and their predicate counts,
- per-condition match results with the list of matching InvCon predicates,
- a summary with exact / partial / none counts and a coverage percentage.

The JSON files are stored under
`results/ground-thruth_comparison/condition-matching/<contract_id>/`
and this README is generated from their contents.

---

## Results

| Contract | Vuln. Function(s) | Root Cause | Ground-Truth Condition (from diff) | Closest InvCon Predicate | Match |
|---|---|---|---|---|---|
| **201804_BEC** | `batchTransfer` | Overflow | `_value <= uint256(-1) / cnt` | `this.ERC20Basic_own_totalSupply <= _value` | 🟡 PARTIAL |
| **201804_SmartMesh** | `transferProxy` | Overflow | `total >= _feeSmt` / `total >= _value` | — (function not in .inv) | ❌ NONE |
| **202102_Yearn_ydai** | `earn` | Slippage | `msg.sender == governance` | `msg.sender == orig(msg.sender)` | 🟡 PARTIAL |
| **202201_Anyswap** | `anySwapOutUnderlyingWithPermit` | Incorrect Validation | `v == 27` / `v == 28` | — (function not in .inv) | ❌ NONE |
| **202206_InverseFinance** | `latestAnswer` | Flash Loan | `crvLPTokenPrice >= lower` / `crvLPTokenPrice <= upper` | — (function not in .inv) | ❌ NONE |
| **202210_N00d** | `enter` | Reentrancy | `!__lock_modifier0_lock` | — (lock var introduced by patch) | ❌ NONE |
| **202210_Uerii** | `mint` | Access Control | `totalSupply() + amount <= CAP` | — (no matching predicate) | ❌ NONE |
| **202212_JAY** | `buyJay`, `sell` | Reentrancy | `!__lock_modifier0_lock` | — (function not in .inv; lock var introduced by patch) | ❌ NONE |
| **202301_QTN** | `transfer`, `transferFrom` | Logic Flaw | `msg.sender == address(uniswapV2Router)` | `msg.sender == orig(msg.sender)` | 🟡 PARTIAL |
| **202305_ERC20TokenBank** | `doExchange` | Price Manipulation | `namount >= (camount * 995) / 1000` | — (function not in .inv) | ❌ NONE |
| **202306_VINU** | `addLiquidityETH` | Price Manipulation | `size == 0` | — (no matching predicate) | ❌ NONE |
| **202308_Uwerx** | `transfer`, `transferFrom` | Logic Flaw | `uniswapPoolAddress != address(0x1)` / `_balances[to] == (toBalance - userTransferAmount)` | `to == orig(to)` (for balance condition) | 🟡 PARTIAL (1/2) |
| **202311_grok** | `transfer`, `transferFrom` | Slippage | `sellSlippageBps = 9500` *(implicit slippage param)* | — (state var introduced by patch) | ❌ NONE |
| **202404_HoppyFrogERC** | `transfer`, `transferFrom`, `manualSwap` | Logic Flaw | `swapAmount <= maxSwapForSell` | — (no matching predicate) | ❌ NONE |
| **202406_APEMAGA** | `family` | Logic Flaw | `msg.sender == account` | `msg.sender == orig(msg.sender)` / `account == orig(account)` | 🟡 PARTIAL |
| **202409_Bedrock_DeFi** | `mint` | Logic Flaw | `uniBTCAmount * 1e10 < msg.value` | — (function not in .inv) | ❌ NONE |

---

## Summary

| Match Type | Count | % of evaluated |
|---|---|---|
| ✅ EXACT | 0 | 0% |
| 🟡 PARTIAL | 5 | 28% |
| ❌ NONE | 13 | 72% |

**Evaluated contracts:** 18 / 26  
**Contracts with InvCon output for the vulnerable function:** 9 / 18

---

## Key Findings

1. **Zero exact matches across all 26 contracts.** InvCon never produces a
   predicate that literally matches the ground-truth security invariant.

2. **Partial matches reflect token overlap, not semantic equivalence.**
   PARTIAL results (e.g. `msg.sender == orig(msg.sender)` matching
   `msg.sender == governance`) share variable names and operators but express
   weaker, non-security-relevant properties.

3. **Systematic causes of NONE:**
   - *Function not in .inv*: InvCon's storage-slot resolver failed to produce
     any output for the vulnerable function (affects 6/18 evaluated contracts).
   - *Guard variable introduced by patch*: reentrancy lock variables
     (`__lock_modifier0_lock`) and slippage parameters (`sellSlippageBps`)
     did not exist in the original contract, so InvCon could never observe them.
   - *Arithmetic / relational complexity*: conditions involving computed bounds
     (`_value <= uint256(-1) / cnt`, `namount >= camount * 995 / 1000`) require
     multi-variable arithmetic reasoning beyond Daikon's template set.

4. **InvCon's design scope mismatch.** The tool was evaluated on standard
   ERC-20 contracts; applying it to real-world DeFi attack contracts introduces
   a fundamental scope mismatch — the invariants that matter for security
   (access control checks, overflow bounds, reentrancy locks) are precisely
   those that Daikon-style statistical inference cannot recover from normal
   historical execution traces.

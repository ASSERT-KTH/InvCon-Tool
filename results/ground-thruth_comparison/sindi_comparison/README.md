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
python3 compare_invcon_sindi.py \
    --daikon-dir ./daikon \
    --ground-truth ./ground_truth.csv \
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
| `verdict_raw` | Sindi's textual verdict (the best one obtained across all invariants) |

The possible values of `verdict_raw` are Sindi's four official strings:

- `The predicates are equivalent.` — the InvCon invariant is equivalent to the ground truth
- `The first predicate is stronger.` — the InvCon invariant is stronger
- `The second predicate is stronger.` — the ground truth is stronger
- `The predicates are not equivalent and neither is stronger.` — no relationship

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
- `unmappable` — Daikon syntax recognized as non-translatable
  (`one of {...}`, `size(...)`, `elements`, `getValueOfKey(...)`)
- `unknown` / `error` — non-classifiable row / comparison error

---

## The Daikon→Sindi preprocessor

InvCon's invariants are in a **Daikon dialect**. Most lines are already
accepted by Sindi's tokenizer; only the array/accessor syntax breaks it.
`daikon_preprocessor.py`:

- **maps** `X[].getValue()` → `X_getValue`, `sum(...)` → an opaque symbol
  `sum_...`, **without renaming the variables** (names stay *mangled*, for
  fidelity to the original tool)
- **filters out** meta-statements and object identity (not boolean predicates)
- **flags** non-translatable syntax as `unmappable` instead of crashing the
  comparison

`orig(x)` is **not** touched: Sindi already accepts it as a symbol.

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

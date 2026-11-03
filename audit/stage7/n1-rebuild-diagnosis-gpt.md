## Diagnosis

**The sole difference is an added `N1/version` file containing `1\n` (bytes `31 0a`).** No frozen file’s contents changed.

| N1-relative path | Comparison with freeze-era reconstruction |
|---|---|
| `version` | Added; absent at freeze |
| `store/bars_4h/1.parquet` | Byte-identical |
| `store/events_forum/1.parquet` | Byte-identical |
| `store/funding/1.parquet` | Byte-identical |
| `store/policy.json` | Byte-identical |
| `venue/execution.json` | Byte-identical |
| `venue/rules.json` | Byte-identical |

The manifest records an aggregate hash, not per-file hashes. I reconstructed N1 using the generator and store source from freeze commit **`e2ddba46be1c12ff5ed55c2190ddf694c09d57af`**; it exactly reproduced the manifest:

```text
Frozen / freeze-era reconstruction:
b9927e145361807b7d65608889f76835eeabce6b0273c26c22d8a35fbf406f22

Current reconstruction:
5a0e5a1a14745d706556cda3aaa17b0a4e398f7101a293cb18f7e598091d809f
```

Computing the current hash with only `version` omitted—without modifying any files—also reproduced the frozen hash exactly.

## Cause and commit

**A market-writer artifact change**, not changed synthetic values, store encoding, policy, missing data, or toolchain drift.

Commit **`b2c000710b0c45d87a00376117d11cee52ba8b16`** added this line at **`gate/markets.py:226`**:

```python
(root / "version").write_text(f"{fetched_at}\n")
```

`reference/differential.py:55–62` hashes every relative filename and its bytes, so the additional file changes N1’s identity. The check at **`reference/differential.py:199–201`** consequently fails before verdict or execution comparisons begin.

## Proposed fix

Make the frozen-corpus differential reconstruct its fixtures using the **freeze-pinned reconstruction source and dependencies**, rather than today’s evolving production writer. Continue passing the manifest’s existing dataset versions to execution.

Keep the manifest, corpus, and complete-file hash check unchanged. Do **not** globally ignore `version`, rewrite the expected hash, or revert production version pinning.

**Validation:** ran through `nix develop -c`, with memory/swap caps and a fresh `TMPDIR` under `/tmp/opencode`, removed afterward. No repository changes or commits; no full run-equivalence claim is established by this N1 diagnosis.

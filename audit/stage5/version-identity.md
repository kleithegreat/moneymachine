# Raw version identity after the recorded rewrites (stage 5, 2026-10-23)

A raw version is named by its fetchedAt, the time of our fetch. That time is an observation (the witness the
derivation reads), so it is never re-stamped. A version's identity is its name together with its file's sha256.

- **Purge, 2026-10-22 (human decision).** Files `data/sources/discourse/1792408757368.parquet` and
  `1792701110136.parquet` were rewritten without the six forums' rows. `purge-20261022.json` lists each one's
  sha256 before (that identity is retired, and its content deleted) and after (the identity of the retained
  rows).
- **Migration, 2026-10-19.** It removed a stored knownAt column from `1792408757368.parquet`, keeping rows and
  fetchedAt. Its earlier sha256 was not recorded, so that identity cannot be named here. Since the C0.4
  amendment, no stored knownAt is read in any case.
- **Binding.** Every derived version's lineage manifest (`lineage-*.json`) lists the sha256 of each raw file it
  read (`raw_files_sha256`), and the sha256 of the records it read at its cut. A derived version is therefore
  tied to the post-rewrite identities, and a later change to any raw file is detectable.

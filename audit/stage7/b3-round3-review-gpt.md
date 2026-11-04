# Review of B3 round 3 (59077b4)

GPT (`openai/gpt-6.1-sol#high`, opencode), independent review from a clean worktree (no `data/`), at `59077b4`; started 2026-11-04 10:01 UTC (05:01 EST), reply received 10:09 UTC (05:09 EST). The reply as given, tool transcript omitted.

## Findings

1. **High — The size definition weakens the production comparison below its stated floor.**  
   `audit/stage7/b3-draft/c76-revision.md:27–29`; `audit/stage7/b3-draft/resolver_suite.py:585–592`.  
   The counter includes evidence keys, outside-U keys and keys with empty timelines. Reproduction gives the advertised **3,020 pairs**, but only **932** concern keys mapped into U, and only **552** concern such keys with any timeline entry. Thus the suite falls below 1,000 delivered-key/query comparisons while declaring “loosens nothing,” contrary to `audit/criteria.md:1084` and the preserved requirement in `audit/decisions.md:496`. **Outcome:** C7.6 can pass without its required volume of production-delivery comparisons.

2. **High — The lineage mapping excludes the store’s actual Arrow string type.**  
   `audit/stage7/b3-draft/rules-revision.md:135–139`.  
   Declared string cells explicitly accept Utf8 and LargeUtf8, but the separate `upstream` mapping specifies only Utf8. A synthetic write through the current `Store.write` produces `upstream: large_string`. There is no stated LargeUtf8 lineage mapping: rejecting it excludes ordinary store output; accepting it adds an unwritten conversion. **Outcome:** Python and Rust can disagree on whether derived datasets decode, blocking migration or changing derived deliveries.

3. **High — “Holdout staging” does not require the staging boundary it names.**  
   `audit/stage7/b3-draft/c76-revision.md:42–43`.  
   Reading every event time “before any revision is resolved” permits eagerly opening all value columns, then checking event times, then resolving. That satisfies this wording while violating `kernel/SOURCES.md:169–178`, which permits only event-time reads before the holdout check. The draft supplies no executable loader-staging test; `lean_check.py` exercises resolution, not admission or column access. The port plan’s separate attack 18 remains future work. **Outcome:** this named C7.6 test could pass despite premature holdout-value access.

4. **High — The integer domain has neither a complete Parquet image nor a defined numeric-overflow rule.**  
   `audit/stage7/b3-draft/c76-revision.md:20–24`; `audit/stage7/b3-draft/rules-revision.md:49–52,123–124,137–139`; `reference/lean/Main.lean:461–464`.  
   JSON integer cells are not restricted to Int64: an integer `trades` or slot of \(2^{63}\) decodes under the text, but cannot retain its integer kind in any permitted Parquet type. Nevertheless, the loader procedure only exempts texts that do not decode as JSON. Separately, a syntactically integer settlement rate of \(10^{400}\) is a number under the payload rule, but Lean’s `numBits` returns `none`; reproduction produces an empty timeline. The prose never specifies that integer overflow makes a numeric payload unusable. **Outcome:** valid versus unusable revisions, and which cases loaders must compare, differ between implementations.

5. **Medium — The checker passes with a selected generated case missing.**  
   `audit/stage7/b3-draft/lean_check.py:66–82`.  
   Every comparison uses truncating `zip`, without checking output cardinality. I reproduced exit status **0** after removing the final generated result: the report showed only 118 outcomes while still reporting the input suite’s 3,020 pairs. This contradicts `audit/criteria.md:984`, where every selected case counts and a missing case fails. **Outcome:** incomplete differential evidence can receive a passing result.

6. **Medium — Lean lists one signed-zero entity twice.**  
   `reference/lean/Main.lean:383–384,487–488`.  
   `entityKey` correctly equates `0.0` and `-0.0`, but output-key enumeration deduplicates raw `Cell` lists using bitwise constructor equality. Two evidence revisions with entity `["a", 0.0]` and `["a", -0.0]` therefore produce **two output keys containing the same combined timeline**. The rules require one key because both zeros are one cell value (`rules-revision.md:41–47`). **Outcome:** a conforming independent resolver fails comparison against Lean, and diagnostic key counts can be inflated. Existing signed-zero hand coverage tests values, not entities.

7. **Medium — `retraction keeps slot` still does not certify slot preservation.**  
   `audit/stage7/b3-draft/resolver_suite.py:667–668`.  
   The predicate compares the preceding slot with the event time and the retraction’s stored slot, but never checks that the **returned retraction slot equals the preceding slot**. Replacing that returned slot with an arbitrary wrong integer still awards the tag. **Outcome:** the frozen coverage floor can certify incorrect retraction-slot behavior. The discriminating hand cases help, but do not make this certificate truthful.

8. **Lower — The retraction observation definition contradicts its output format.**  
   `audit/stage7/b3-draft/rules-revision.md:72–74,121–124`.  
   The observation definition enumerates fetchedAt, knownAt, slot, payload and values, then says “all undefined but the slot on a retraction.” Literally, that undefines fetchedAt and knownAt too; §7 and Lean retain both. The intended restriction must explicitly concern values and role payload only. **Outcome:** independently implemented retraction observations can disagree on required timestamps.

**Verdict: revise first.**

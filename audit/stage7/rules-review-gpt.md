[0m
> build · gpt-6.1-sol
## Freeze blockers, most important first

1. **`floor` can overflow; the specification explicitly says it cannot.**  
   For `T = −4611686018427387904`, `P = 3`, the result is `−4611686018427387906`, below the permitted range. Implementers following the range rule and the operator description will disagree.

   **Replace the evaluation clause with:**
   > `floor`: compute the exact integer `F = P × ⌊T/P⌋`. Return `R_OVERFLOW` if F is outside [−2^62, 2^62−1]; otherwise return F.

2. **A checked rule can expose data early.**  
   `field(eventTime)` and `floor(field(reportedTime), hour)` pass checking but can precede actual availability. Nothing connects the AST result to C7.3’s evidence requirements.

   **Replace the opening claim and add an integration requirement:**
   > The AST computes a candidate availability time. Successful checking does not establish that this time is trustworthy. Before delivery, the certified availability procedure below MUST compute the effective knownAt. Neither the feed nor the AST may bypass that procedure.

3. **The claimed-time/witness/prospective policy is absent.**  
   Missing evidence cannot simply mean a missing operand: a witness-only row may qualify, whereas an unwitnessed, unqualified claim must be prospective-only. Multiple witnesses also need an aggregation rule.

   **Add:**
   > For each immutable revision, the verifier identifies an optional qualified claimed-time candidate C and a fixed set of qualifying independent witness times. C is permitted only when its timestamp is protocol-enforced or server-set and the required live test passed. Let W be the maximum of that witness set, when nonempty. Historical availability is max(C,W) over the candidates that exist. If neither exists, availability is the trusted recorder’s first-observation time for that revision, and the row is prospective-only. Evidence selection and qualification are pinned by the certificate; feed assertions alone cannot supply them.

   Using the maximum witness is a conservative proposed convention; freeze an explicit alternative if that is not intended.

4. **Later revisions and tombstones can inherit an old timestamp and be backdated.**

   **Add:**
   > Every later-observed revision, including a tombstone, has an authoritative revision-observation time assigned by the recorder. Its effective knownAt is no earlier than that time. An earlier revision’s timestamps or witnesses do not establish availability of the later revision. This bound is mandatory and cannot be removed by an AST or a corrected rule.

5. **A derived rule need not mention every required input, and may floor an input backward.**  
   Declaring dependencies does not enforce C7.4’s latest-input-plus-delay requirement.

   **Add:**
   > The transformation declares the complete required-input set for each derived observation, including inputs establishing coverage and mapping. Let K be their maximum effective knownAt and D the pinned nonnegative processing delay. The derived observation’s effective knownAt is at least K+D, independently of the AST’s result. Compute K+D exactly; overflow rejects with `R_OVERFLOW`. An unavailable required input makes the observation unavailable. Unreferenced required inputs still impose this bound.

6. **`deps` has no authoritative resolution contract.**  
   A feed can supply arbitrary early integers; source-level names do not identify which observation or revision was used. Recursive dependency resolution is also unspecified.

   **Add:**
   > Each dependency name identifies an exact upstream observation and revision through immutable lineage. Its supplied value is that revision’s effective knownAt, computed under pinned rules and valid certificates, not a feed-supplied timestamp. Dependency resolution uses the same dataset cutoff and resolver semantics as direct queries. A dependency without a usable knownAt is supplied as absent. Dependency graphs MUST be acyclic; cyclic or unresolved lineage invalidates the dataset before evaluation. No dependency is silently omitted.

7. **C7.6’s full resolver is not specified at all.**  
   The required latest-revision-before-availability behavior, cutoffs, tombstones and corrected rules cannot be implemented from this document alone.

   **Add a normative resolver section:**
   > A declaration defines the logical observation key. Revisions carry a trusted fetch time and a recorder-assigned revision sequence unique within that key. For dataset cutoff C, eligible revisions have fetchTime ≤ C. Select the maximum eligible revision by `(fetchTime, revisionSequence)`, before evaluating availability and independently of query time t. No eligible revision means no observation. A selected tombstone means no observation. Otherwise compute the selected revision’s effective knownAt using the dataset-pinned rule. Deliver it exactly when knownAt ≤ t. Rejection or knownAt > t produces no observation; neither permits fallback to another revision. Do not additionally filter revisions by fetchTime ≤ t.

   **Also add:**
   > Duplicate revision identities, conflicting sequence numbers and malformed revision metadata invalidate the dataset before any delivery. The resolver’s externally observable outcomes and diagnostics are specified in the frozen comparison protocol.

8. **“The dataset version pins it” does not define rule identity or corrected-rule behavior.**

   **Add:**
   > A dataset version pins the exact accepted UTF-8 rule-document bytes, their SHA-256, the declaration/context identity and the rule-language version. A correction creates a new dataset version and any required replacement certificate; it does not mutate an existing version. Every selected revision is evaluated under that version’s pinned rule. Cached knownAt values may be reused only when their rule, context, revision and dependency identities match exactly. Stored outputs of another rule are never authoritative.

9. **Malformed row/dependency inputs have no specified outcome or precedence.**  
   The “strict JSON” paragraph appears under rule documents. It is unclear whether duplicate row keys, excessive depth, malformed JSON or a non-object root are globally rejected or handled only when referenced.

   **Add:**
   > Rules, rows and deps are supplied as raw JSON texts. Rule parse or structural failures produce `E_RULE`. Before expression evaluation, parse row and deps completely and require each root to be an object. Invalid JSON, duplicate keys, excessive depth or a non-object root in either input produces `R_FIELD_TYPE`, before any expression rejection. Valid unreferenced members are permitted and receive no expression-level type or range checks.

   Thus a duplicate key in an unused nested member is rejected globally, while a valid but out-of-range unused integer is ignored.

10. **The accepted JSON syntax and string equality are underspecified.**  
    Careful parsers differ on BOMs, unpaired surrogates, nonfinite numbers, trailing content and escaped duplicate names.

    **Add:**
    > JSON texts MUST be UTF-8, without a BOM, and contain exactly one RFC 8259 JSON value followed only by JSON whitespace. Comments, trailing commas, NaN and Infinity are invalid. Decoded strings MUST contain only Unicode scalar values; unpaired surrogate escapes are invalid. Keys and names are compared by their decoded scalar sequences, without normalization, case folding or locale rules. Duplicate-key detection occurs after escape decoding, in every object. Names are literal keys, not paths. Any nonempty scalar string is a permitted NAME.

    This makes `"t"` and `"\u0074"` duplicate keys, but does not equate canonically equivalent Unicode spellings.

11. **“JSON integer” needs one lexical and mathematical definition everywhere.**  
    Row/dependency wording is clearer than constant/version wording. Ordinary Python and Rust JSON decoding can also lose number spelling or precision before checking.

    **Replace the scattered number definitions with:**
    > An integer token matches `-?(0|[1-9][0-9]*)` using ASCII digits. Its value is the exact mathematical integer; `-0` is zero in every position. Other valid JSON number tokens are not integers, regardless of mathematical value. Preserve this distinction without binary-floating-point conversion. Integer tokens have no additional digit-count limit: out-of-range rule constants produce `E_RULE`; out-of-range referenced row/dependency integers produce `R_OVERFLOW`. Fractional or exponent tokens in referenced values produce `R_FIELD_TYPE`, even if their magnitude exceeds the range.

    Consequently, `{"ms": -0}` is valid, but a floor period of `-0` is rejected.

12. **“Every intermediate value” can accidentally constrain implementation arithmetic.**  
    One implementation might reject an overflowing helper calculation even when the AST node’s mathematical result is valid.

    **Replace that sentence with:**
    > The range restriction applies to each expression node’s returned value, including leaf values, not to implementation-private arithmetic temporaries. Compute each operator’s mathematical result exactly and then range-check that node’s result. Machine overflow, wrapping, saturation and floating-point approximation are never language semantics.

13. **Rule rejection is not clearly distinguished from rejecting one row.**  
    “A row whose rule is rejected” could encourage skipping rows or substituting defaults after `E_RULE`.

    **Replace it with:**
    > `E_RULE` rejects loading the rule and any binding requiring it, before any row is evaluated or delivered. It is not a per-row outcome and permits no default rule. A checked rule’s runtime rejection leaves that observation without knownAt and permits no delivery or older-revision fallback.

    **Make the evaluation-order consequence explicit:**
    > Stop at the first rejecting operand in depth-first, left-to-right order. Evaluate every operand reached by that order; `max` has no value-based short-circuit. Optimizations MUST preserve the same value or rejection code.

14. **C7.6’s frozen AST suite is absent, and its counts are not operationally defined.**

    **Add a normative suite requirement:**
    > Before any implementation, freeze and commit the complete fixture inventory, raw JSON inputs, contexts, expected outcomes, generation procedure, seeds and comparison procedure. Include at least 1,000 distinct accepted-rule/input pairs, with at least 100 distinct pairs in each of floors, maxima, offsets and composition. Categories may overlap. Composition means an operator occurring inside another operator’s operand. Include hand-computed boundaries and ±1 ms, negative timestamps, all rejection codes, malformed rules, and floor underflow. All selected cases count; omissions, crashes, timeouts and malformed outputs fail the comparison.

15. **The independent implementations lack a frozen input/output contract.**  
    Passing already-decoded JSON objects would erase exactly the lexical distinctions this specification requires.

    **Add:**
    > The comparison protocol transports rule, row and deps JSON as source text, not as previously decoded numbers or maps. It specifies context encoding and distinguishes check rejection, evaluation rejection and successful Time results. Successful times are compared as exact integers; rejection codes are compared exactly. No host exception, parser diagnostic or resource-limit outcome counts as a language result.

    **For the resolver, add:**
    > Freeze at least 1,000 queries over multi-revision fixtures with exact expected selected-revision identities, delivered values, knownAt values and absence/rejection outcomes. Cover inclusive cutoff and availability boundaries, revision-order ties, tombstones, unavailable latest revisions without fallback, and corrected rules with stale cached outputs present.

These last two suites and the resolver contract must be normative companions if they are not included in `RULES.md`; otherwise “from this document alone” does not cover C7.6.
exit=0

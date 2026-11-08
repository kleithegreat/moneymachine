GPT 6 (high) deep research (web, ChatGPT), 2026-11-07, same prompt as the Argon report beside it. Model output: citations unverified.

# Designing an LLM-Native Trading Strategy DSL: Learnability, Expressivity, Safety, and Evaluation

## Executive summary

- **Bend 2 is genuinely an AI-oriented, proof-aware language, but the strongest claim — that an LLM can rapidly learn it from scratch and then build substantial correct programs — is not yet supported by controlled evidence. Confidence: High.** The current language is Python-shaped, pure and affine, uses dependent types, separates laws from proofs, exposes proof holes/goals, and ships its language guide directly through the CLI. Its repository explicitly tells coding agents to read `bend guide` before writing code. However, I found demos, reproducible performance benchmarks, community anecdotes, and agent-oriented documentation — not a randomized benchmark comparing LLM performance in Bend against alternative unfamiliar languages or surfaces. Bend also does have a `Base` library today, so “no standard library” is no longer literally accurate; the library is simply small and omits common facilities such as HTTP, TLS, JSON, and regex. citeturn125277search1turn929568search1turn929568search9

- **The literature supports “learnable from context” only conditionally: familiarity, examples, documentation, and verifier interaction matter a great deal, while merely having a small grammar is not enough. Confidence: High.** MultiPL-E and McEval show large cross-language variation correlated partly with language representation in training; newer experiments on unfamiliar and esoteric languages show that models often retain the right algorithmic idea while failing to realize it correctly in the unfamiliar syntax. In-context examples can materially improve this, but some genuinely unfamiliar languages remain extremely difficult even with documentation. citeturn177401search0turn396214search4turn396214search5turn256013search6turn256013academia8

- **The strongest language-design evidence for agents is not “make syntax pleasant”; it is “make incorrect states impossible or cheap to diagnose.” Confidence: High.** Lean, Dafny, Coq, type-constrained generation, and SWE-agent all show the value of machine-checkable intermediate feedback. Verifier-guided search can produce very large gains: VerMCTS reports more than a 30-percentage-point increase in average pass@5000 over repeated sampling, while type-constrained decoding more than halves compilation errors in its evaluation. SWE-agent similarly found that syntax-aware editing, concise observations, and explicit confirmation of successful-but-silent actions materially changed agent performance. citeturn740164search12turn177401search7turn399600search1

- **Human ergonomics do not disappear for agents; they change form. Confidence: High.** Typing effort, mnemonic burden, punctuation aesthetics, and verbosity matter less intrinsically. Ambiguous semantics, hidden defaults, nonlocal dependencies, poor diagnostics, and several equivalent idioms still matter because they increase inference uncertainty and repair loops. New agent-specific costs include token count, tokenization instability, context dilution, and structured-output failure modes. Recent work finds measurable sensitivity to tokenization and deep structured formats. citeturn177401search4turn416462search7turn416462search3

- **Keeping JSON as the trusted interchange format is sensible, but requiring agents to reason and author directly in deeply nested JSON is not obviously optimal. Confidence: High.** Studies of format restrictions are mixed: the 2024 “Let Me Speak Freely?” study found reasoning degradation under stricter structured-output requirements, while a 2026 causal analysis found no causal format effect in most tested scenarios and stronger reasoning models were more robust. A newer “format tax” study likewise argues that decoupling reasoning from final formatting recovers much of the loss in affected models. The safe conclusion is to benchmark your actual Claude-family agents, not assume JSON is neutral. citeturn422979search0turn422979search2turn422979search8

- **Your current safety architecture is unusually well aligned with the strongest restricted-language designs: pure interpretation, bounded resources, explicit data access, dimensional typing, causal execution, and a small trusted evaluator are all well-supported design patterns. Confidence: High.** Dhall, Starlark, CEL, eBPF, Scilla, Move, synchronous languages, and typed FRP all restrict effects or computation so that important properties become statically or mechanically checkable. The important lesson is that restricted expressivity is valuable when the restriction corresponds to a property the checker can enforce, not merely when the language is small. citeturn956742search0turn956742search4turn956742search7turn956742search5turn119328academia9turn240116search9

- **Counting submitted evaluations is necessary but not always sufficient for false-discovery control if one evaluation contains substantial hidden optimization. Confidence: High.** White’s Reality Check, Hansen’s SPA test, the Deflated Sharpe Ratio, PBO/CSCV work, and the wider factor-mining literature all treat model selection and repeated specification search as sources of selection bias. A richer strategy that internally chooses among many parameterizations or fits a highly flexible function can embody more effective search than a fixed formula even if both consume one nominal evaluation. Your statistical accounting should therefore distinguish “one evaluated fixed hypothesis” from “one evaluation that performs its own data-adaptive model selection.” citeturn134827search7turn134827search1turn134827search4turn134827search3turn528713search5

- **The most valuable near-term changes are surface/tooling changes, not new semantic power. Confidence: High.** Based on your own campaign evidence — extremely low type-error rates, more input-availability failures, rediscovery of the hold idiom, and low consumption of the evaluation budget — the dominant opportunities are discoverability, explicit names for existing semantics, compact authoring syntax, checker diagnostics, examples, and feedback loops. There is little evidence that lack of expressivity is currently limiting agents. Semantic features should face a substantially higher bar than surface sugar.

- **“Optimal” should be defined as search power at fixed statistical risk and evaluation budget, not code-generation convenience alone. Confidence: High.** The key end-to-end metric is probability of recovering a planted real edge at a fixed evaluation budget while maintaining calibrated false-discovery behavior on null markets. First-attempt validity, tokens, repair cycles, and abandonment are intermediate metrics; they matter because they affect how much useful hypothesis search the agent can perform before the statistical budget is exhausted. This mirrors agent-interface research, where interface design can change task success without changing underlying model capability. citeturn399600search0turn399600search4

## Languages LLMs learn without pretraining

### What Bend 2 actually is

The current Bend 2 is substantially different from the original Bend/HVM story. HVM remains a low-level parallel runtime/IR and is explicitly described as not being intended for direct human use; Bend is the high-level language. Bend 2’s current guide describes its syntax as Python-shaped, its semantics as closer to Haskell and Lean, and its resource discipline as affine. It is pure except for explicit `IO`, supports dependent types because types are themselves terms, and treats a proposition as a type whose proof is an ordinary definition. citeturn981174search7turn125277search1

The proof workflow is deliberately simple at the surface. A project can declare laws in `LAWS.bend`; corresponding definitions in `PROOF.bend` prove them. The normal checker validates them, while `--verdict` translates the program into a smaller BendTT calculus and checks it again with a Lean-formalized kernel. The guide exposes holes and goals: `?TODO` leaves a proof open, `?name` prints a goal, and failed proof steps print expected versus observed terms. The project’s own description explicitly positions this fast feedback loop as suitable for agents. citeturn125277search1turn729425search2

Bend also imposes a nontrivial termination discipline. The current guide says live recursive code must terminate; proof/type-erased portions are treated separately, and the Lean formalization argues that accepted live code halts and cannot inhabit `Empty`. This is relevant to your DSL because it illustrates a broader pattern: semantic restrictions become much more useful to an agent when the checker explains them locally and cheaply. citeturn729425search1turn729425search2

The project’s AI-native positioning is real rather than retrospective. The README explicitly instructs users to tell an agent to run `bend guide`, use laws, and check proofs; the project now publishes a dedicated guide for Claude Code, Codex, and similar agents. It also includes AI-authored documentation sections. However, these are **designer claims and workflow recommendations**, not controlled measurements of learnability. citeturn929568search0turn929568search1turn929568search3

There is also evidence that agents can produce real Bend artifacts, but its evidentiary strength is limited. The repository contains application demos and proofs, and third parties report using agents to port existing programs to Bend shortly after release. That establishes feasibility, not comparative learnability: the experiments are anecdotal, tasks differ, agents had tool access, and failed or abandoned efforts are not systematically sampled. citeturn729425search0turn929568search6

Likewise, the project’s performance evidence should not be conflated with language-learnability evidence. Bend publishes pinned, reproducible CPU and GPU benchmarks, and some independent performance repositories exist, but these answer whether generated Bend programs run fast, not whether an LLM learns the language efficiently. citeturn929568search4turn729425search6

**Conclusion: Bend validates the architectural intuition that a new language can be made explicitly agent-facing through familiar syntax, bundled documentation, holes, a fast checker, and mechanical proof obligations. It does not yet validate the stronger claim that these features make Bend unusually easy for LLMs to learn relative to competing designs. Confidence: High.**

### What research says about unfamiliar languages

MultiPL-E is the foundational broad comparison. It translated HumanEval and MBPP into 18 additional languages and found that performance varies substantially by language; language popularity correlates with performance, but the relationship is not deterministic, and some niche languages perform surprisingly well. It also found limited benefit from type annotations in the gradually typed languages it tested. This argues against a simplistic rule such as “more explicit syntax always improves LLM code generation.” citeturn177401search0turn396214search1

McEval broadened this picture to 40 programming languages and 16,000 samples, again finding substantial multilingual variation. The MultiPL-T work goes further: it treats low-resource-language performance as a data-distribution problem and shows that validated translated training data materially improves models on Julia, Lua, OCaml, R, and Racket. This supports a strong role for pretraining familiarity and validated examples. citeturn396214search4turn177401search3

The most directly relevant 2026 experiment is *Syntax Without Semantics*. It introduces PyLang, deliberately absent from pretraining, and reports that even after fine-tuning models learned surface syntax faster than they acquired implementation fidelity. The models often selected essentially the same algorithm they would use in Python but failed to express it successfully in PyLang; Python retained up to a 19-percentage-point advantage. That is almost exactly the failure mode a new strategy DSL should fear: the agent may understand the trading idea while mis-encoding it. citeturn396214search5

Esoteric-language work gives mixed but informative results. Amjith et al. found that documentation plus sparse examples enabled models to generate some correct programs in unfamiliar languages, and verified examples fed back into later prompts improved performance substantially: for example, their reported Pyth EsoEval accuracy rose from 16.67% to 30.82%, and Minipy HumanEval from 51% to 65%. By contrast, EsoLang-Bench found frontier-model accuracy of only 0–11% across five very low-resource esoteric languages, with few-shot prompting and self-reflection failing to solve harder tiers. These are not contradictory: language regularity, similarity to learned languages, documentation quality, and task difficulty all matter. citeturn256013search6turn256013academia8

This makes Bend’s Python-like surface a plausible advantage. It lets the model reuse token patterns, indentation conventions, function syntax, algebraic-data-type concepts, and proof concepts learned from Python/Haskell/Lean-like corpora. But the literature does not isolate “syntax familiarity” cleanly from training frequency or ecosystem documentation, so the effect size is unknown. citeturn177401search0turn396214search5

**Conclusion: similarity to high-resource languages is probably more important than extreme syntactic minimalism for a language learned in context. A tiny alien grammar can still create a large implementation-fidelity gap. Confidence: Medium-high.**

### Which properties plausibly help

**Syntactic regularity and a small grammar.** Grammar simplicity reduces the set of malformed outputs and makes constrained decoding easier, but there is weak direct evidence that “smallest grammar wins” for semantic correctness. Grammar-constrained decoding can guarantee CFG-level validity, and newer work can enforce even type constraints during decoding; however, valid syntax does not guarantee that the agent has expressed its intended algorithm. citeturn422979search3turn177401search7

**Similarity to pretrained languages.** Evidence is considerably stronger. MultiPL-E, McEval, MultiPL-T, and unseen-language experiments all point toward a strong data/familiarity effect. A compact Python/function-call-like surface is therefore a better default hypothesis than a bespoke symbolic notation unless the latter provides substantial other advantages. citeturn177401search0turn396214search4turn177401search3turn396214search5

**One canonical way to express each operation.** This is intuitively attractive because it reduces equivalent surface forms and repair branching, but I found little controlled LLM-specific evidence isolating this variable. The case is stronger as an engineering prior than as an empirical finding. Canonical forms also help auditing and caching independent of agents. **Confidence: Medium-low.**

**Explicit types, units, and holes.** Types help most when they are mechanically active rather than explanatory decoration. Type-constrained decoding reduces compilation errors by more than half in the TypeScript experiments, while formal-proof systems expose exact goal states that can drive search. Bend’s proof holes, LeanDojo’s interactive proof state, and CoqPilot’s hole-filling workflow all implement this pattern. citeturn177401search7turn740164academia10turn740164search6

**Checker and verifier loops.** This has some of the strongest evidence in the whole review. VerMCTS combines LLM generation, partial-program verification, and tree search and reports more than a 30-point increase in average pass@5000 relative to repeated sampling. DafnyPro reports improvements across four benchmarks, including 86% correct proofs on DafnyBench for one configuration versus 70% for its base model. Leanabell-Prover-V2 likewise reports gains after integrating Lean verifier feedback into reinforcement learning. citeturn740164search12turn740164search1turn740164academia11

**Error-message quality.** For agents, the evidence suggests that *actionable state* is more important than prose friendliness. SWE-agent found concise search output, syntax checking on edit, fixed-size file views, and explicit confirmation of empty command output useful enough to bake into its ACI. Human studies of “friendlier” LLM-generated compiler messages are much less consistent, which is a warning not to optimize diagnostics for conversational warmth. citeturn399600search1turn177401academia11

**Token efficiency.** This matters both economically and cognitively. TokDrift demonstrates that semantics-preserving changes in code tokenization can change model behavior across nine code models, while CodeStruct reports that structured AST-aware tools reduced token use by 12–38% for most evaluated models while improving SWE-bench performance. Token efficiency should therefore be measured, but not by character count alone: token boundaries and the amount of irrelevant context matter. citeturn177401search4turn416462search5

**Documentation by example.** This is strongly supported. Retrieval experiments on unfamiliar APIs found gains of 83–220% and identified code examples as the most useful part of API documentation; esoteric-language experiments similarly found strategically selected verified examples useful. A small DSL should therefore have a compact reference plus many canonical examples, preferably retrievable by construct or error code. citeturn177401academia10turn256013search6

**Conclusion: the best-supported combination is familiar surface syntax + canonical forms + mechanically enforced types/units + extremely cheap checker interaction + concise diagnostic state + a corpus of verified examples. Grammar size alone is secondary. Confidence: High.**

### JSON, structured output, and agent ergonomics

The evidence on structured formats has evolved. Tam et al.’s 2024 EMNLP study found that requiring structured formats such as JSON or XML could reduce reasoning performance, with stricter constraints producing larger declines. Their recommended pattern was effectively to separate natural reasoning from final formatting. citeturn422979search0

Later work makes the claim more model-dependent. A 2026 EACL causal study found no detectable causal impact of structured output in 43 of 48 tested scenarios, and found reasoning-oriented models more robust than older general models. The 2026 “Format Tax” study still observes substantial degradation in several open-weight models, but reports that newer closed models are often much less affected and that decoupling reasoning from formatting recovers much of the loss where it exists. citeturn422979search2turn422979search8

Separate from reasoning quality, complex JSON remains a generation problem. SchemaBench reports that contemporary models still struggle on complex schemas; work on JSON placement shows that models can produce syntactically valid output while assigning correct values to the wrong hierarchy level. DeepJSONEval was created specifically because deeper nested structures expose weaknesses that flat JSON does not. citeturn416462search7turn416462search3turn416462academia6

For your DSL, this suggests a useful separation: JSON can remain the canonical, hashable, trusted AST consumed by Rust and reflected in Lean, while agents receive an optional compact authoring syntax that compiles deterministically to exactly the same AST. That gives you the audit benefits of JSON without assuming JSON is the best cognitive surface for the model.

Human ergonomics split into three classes. Typing effort, punctuation convenience, remembering long identifiers, and visual aesthetics become relatively less important. Ambiguity, nonlocal semantics, silent fallbacks, overloaded operators, and weak diagnostics remain important because they affect inference and repair. New concerns include tokenization, context-window occupancy, repeated schema boilerplate, and nested-record placement errors. citeturn177401search4turn416462search3

**Conclusion: ergonomics matter at least as much for agents as for humans, but the objective changes from comfort and memorability to low-entropy generation, low token cost, local diagnosability, and faithful mapping from intent to semantics. Confidence: High.**

## Expressivity versus safety

### What restricted languages teach

Dhall is a clean reference point for “programmable but deliberately not Turing complete.” It allows functions and types but excludes arbitrary effects and is designed so untrusted expressions can be normalized safely. Its designers explicitly treat inability to safely evaluate malicious input as a language-level defect. citeturn956742search0turn956742search3

Starlark reaches a similar point by a different route. It deliberately resembles Python but removes recursion, unbounded loops, exceptions, reflection, user-defined types, and external side effects. Execution is finite, deterministic, and hermetic under the core language. This is especially relevant to an agent DSL: familiarity need not imply general-purpose power. citeturn956742search4

CEL is even closer to an embedded strategy-expression language. It is non-Turing complete, host-embedded, has access only to data the host explicitly provides, and is designed for predictable-cost expression evaluation. That architecture resembles your trusted-kernel model more closely than a conventional programming language does. citeturn956742search7

eBPF demonstrates another pattern: admit relatively expressive programs only when a verifier can prove enough about each one. The verifier symbolically tracks pointer and register states across paths; modern eBPF permits bounded loops but rejects or limits programs whose verification state explodes. The important lesson is not “never add loops”; it is “admit a construct only when its resource and safety obligations remain statically provable.” citeturn956742search5turn956742search6

Smart-contract languages make the same trade-offs under adversarial inputs and irreversible execution. Michelson uses strict static typing and a formal operational semantics; Scilla deliberately separates pure computation, state transitions, and external communication to improve reasoning about contract behavior; Move’s resource/ability system constrains copying, dropping, storage, and ownership; Clarity explicitly chooses decidability and predictability over unrestricted computation. citeturn119328search0turn119328academia9turn119328search5turn119328search6

Capability and effect systems provide a useful conceptual rule for future DSL growth. Joe-E encodes authority through explicit object capabilities; Koka puts effects in function types and can prove properties such as absence of unhandled exceptions when an effect is absent. Recent work on agent safety likewise proposes making agent actions programs in a statically tracked capability language rather than unconstrained tool calls. citeturn627196search1turn627196search4turn627196search0

Your dimensional-analysis design also has strong precedent. Kennedy’s units-of-measure work formalizes exactly the intuition you are using: numeric type systems can encode dimensions so invalid combinations are rejected statically, and the theory supports dimensional invariance rather than merely lint-style checking. citeturn627196search5turn627196search12

### Temporal leakage and causality

Your “deliver all observations known at the tick, then evaluate each expression once” semantics belongs to the synchronous-language tradition. Lustre treats streams synchronously and statically rejects instantaneous cyclic dependencies unless a delay breaks the cycle. Esterel likewise gives a precise synchronous model for reactive execution and developed causality analyses to reject programs whose instantaneous dependencies are inconsistent. citeturn240116search1turn240116search3turn240116search13

Typed functional reactive programming pushes this further: modal FRP systems use types to enforce causality, productivity, and sometimes bounded memory or absence of time leaks. Simply RaTT explicitly treats causality as a type-level property and rules out certain time/space leaks statically. This suggests a useful design principle for trading DSLs: “past versus current versus unavailable-future” can be a static semantic distinction rather than a documentation convention. citeturn240116search9turn240116search8

Your current point-in-time observation model is arguably stronger than introducing a user-visible temporal type system because the interpreter structurally prevents future reads. That is preferable where possible: a property enforced by the evaluator’s ontology is harder to misuse than one agents must prove individually.

**Conclusion: preserve the present causal-machine semantics unless a new feature can be translated into an equally explicit causal model. Do not expose arbitrary indexing or timestamp arithmetic merely because the checker could sometimes detect misuse. Confidence: High.**

### Finance-specific expression languages

The formulaic-alpha tradition validates the usefulness of small expression trees as a search space. Kakushadze, Lauprete, and Tulchinsky’s “101 Formulaic Alphas” represents signals as explicit mathematical formulas built from price, volume, ranking, correlation, delay, decay, and related operators. The authors report low average pairwise alpha correlation and holding periods from roughly 0.6 to 6.4 days, showing that compact expression languages can encode substantial strategy diversity. citeturn206523academia10

Microsoft Qlib follows a similar model. Its expression engine derives features from operators such as references to past observations, rolling transforms, and arithmetic over OHLCV data; its standard Alpha158 and Alpha360 feature sets are built from this machinery. Current development has also moved toward restricted AST interpretation rather than unrestricted Python evaluation, reflecting the same safety boundary your system already adopts. citeturn206523search4turn206523search5

Automated alpha discovery makes the search-space issue explicit. AlphaGen represents formulaic factors as symbolic expressions and searches them with reinforcement learning; recent AlphaCFG work goes further by defining the admissible factor space with a grammar and explicit size constraints, motivated partly by the inefficiency of unstructured unbounded search. GP research likewise treats expression-tree complexity and bloat as practical problems. citeturn206523search6turn206523search9turn206523search7

This is directly relevant to your node and depth caps. Those limits are not only sandbox protections: they are also hypothesis-class regularizers. They bound the number of compositional degrees of freedom available inside one submitted strategy.

### Does more expressivity increase false discoveries per evaluation?

The statistical literature says clearly that *search* matters, not merely the final number of published formulas. White defines data snooping as reusing the same data for model search or inference and develops a Reality Check for the best model encountered during a specification search. Hansen’s SPA test improves the power and robustness of this family of procedures but still assumes the relevant model universe is represented in the comparison. citeturn134827search7turn134827search1

The Deflated Sharpe Ratio explicitly adjusts for selection bias from multiple testing as well as non-normal returns. Bailey et al.’s probability-of-backtest-overfitting work formalizes the event that the configuration selected as best in sample ranks poorly out of sample, and emphasizes that trying more configurations makes apparent high performance easier to obtain. Harvey, Liu, and Zhu reach a related conclusion in the factor literature: the historical accumulation of hundreds of tested factors requires materially higher evidentiary thresholds than naive single-test statistics. citeturn134827search4turn134827search3turn528713search5

The difficult part for your system is that a “trial” is not necessarily identical to one CLI call. Suppose strategy A is a fixed expression with two preregistered parameters. Strategy B contains an optimizer that chooses the best of 1,000 thresholds using the same historical data before returning a weight. Treating both as one evaluation plainly undercounts the second procedure’s adaptive search. That is an inference from the data-snooping literature rather than a theorem about your specific gate, but it follows directly from its treatment of parameter/configuration search as part of the multiplicity problem. citeturn528713search0turn528713search8

There is a subtler case: a richer expression language may allow an agent to mentally synthesize many alternatives before submitting only one. If the agent has not observed evaluation data while doing so, this is ordinary prior hypothesis construction and does not create data snooping against your market sample. If, however, the agent’s hidden search is conditioned on previous backtest outcomes, shared `history`, or detailed evaluation diagnostics, then unsubmitted variants can influence later submissions. The fact that only submitted evaluations are counted does not automatically account for this adaptive pathway. Selective-inference work treats precisely this issue: hypotheses chosen after inspecting data require accounting for the selection procedure, not merely the final reported set. citeturn528713search7

This distinction should drive feature admission. A primitive that merely abbreviates a fixed deterministic expression does not enlarge the semantic hypothesis class. A primitive that performs optimization, model fitting, search, implicit threshold selection, dynamic feature construction, or learned parameter estimation does.

**Conclusion: semantic expressivity is statistically dangerous when it introduces hidden data-adaptive choice inside an evaluation. Pure compositional expressivity is less dangerous, but still increases the size and complexity of the agent’s searchable hypothesis class and can worsen adaptive reuse of the same evaluation history. Confidence: High for the first statement; Medium-high for the second.**

### A principled admission criterion

A useful feature gate is stricter than “can the interpreter implement this safely?” I would require five things.

First, every threatened safety property must remain machine-checkable: units, point-in-time availability, bounded execution, absence of unauthorized effects, and portfolio invariants must either remain structural properties of the evaluator or acquire explicit static obligations. This follows the eBPF, CEL, Scilla, and effect-system pattern. citeturn956742search5turn956742search7turn119328academia9turn627196search4

Second, resource cost must remain statically bounded or host-bounded in a way the strategy cannot evade. Third, the construct must have a canonical deterministic expansion where possible. Fourth, if the feature performs data-adaptive selection, fitting, optimization, or enumeration, the gate must count or statistically account for the effective inner search rather than treating the whole operation as one trial. Fifth, a feature should demonstrate higher planted-edge discovery power at fixed evaluation budget without raising null-market false discoveries.

That criterion admits surface sugar freely and semantic power cautiously.

**Conclusion: “checker can verify the threatened property” is necessary but not sufficient; the second necessary condition is “the statistical gate can account for any adaptive freedom the construct introduces.” Confidence: High.**

## Defining “optimal” for this use case

The natural objective is not minimal syntax error or maximal expressivity. It is **maximum probability of discovering a real, interpretable edge subject to a fixed evaluation budget, fixed compute budget, and unchanged false-discovery guarantees**. All lower-level UX metrics should be treated as mediators of that objective.

Your present campaign data already gives a useful diagnosis. Two type errors in 231 checks imply that type syntax and units are not currently a major failure mode. Eleven evaluations referencing unavailable market inputs are much more important because they consume scarce statistical budget. Agents independently rediscovering “undefined means hold” indicates semantic discoverability debt, not lack of expressive power. Low use of the 100-evaluation budget suggests that either agents stop early, lack enough productive ideas, or perceive evaluation as expensive enough to self-ration. Those hypotheses should be distinguished experimentally rather than assumed.

A useful measurement model is:

| Objective | Operational metric | Why it matters |
|---|---|---|
| Surface validity | Fraction of first submitted candidates passing parse/type/unit/resource checks | Measures authoring friction without spending statistical budget |
| Semantic input validity | Fraction referencing only available point-in-time inputs | Directly prevents wasted evaluations |
| Repair efficiency | Checker turns, tokens, and wall-clock time until first valid AST | Measures cost of feedback loops |
| Evaluation efficiency | Evaluations consumed per distinct mechanism-level idea | Separates syntax iteration from statistical search |
| Representation fidelity | Human/LLM-judge plus structural comparison of intended mechanism versus submitted AST on controlled tasks | Detects “right idea, wrong realization,” the unfamiliar-language failure mode |
| Expressivity abandonment | Fraction of transcripted ideas explicitly abandoned or distorted because they could not be represented | Detects genuine DSL limitations |
| Search power | Probability of discovering a planted edge at budget 10/25/50/100 | Primary positive objective |
| Null calibration | Family-wise error/FDR under null synthetic markets under the exact campaign/gate protocol | Hard safety constraint |
| Complexity | AST nodes, depth, number of parameters, number of distinct primitives, and a prespecified complexity score | Proxy for effective flexibility |
| Audit quality | Ability of an independent reviewer to reconstruct causal mechanism and semantics from AST + mechanism field | Preserves the reason for using a DSL |

The strongest prior work on agent interfaces says to treat the interface itself as an experimental object. SWE-agent’s ACI study shows that altering commands and observation formats can substantially change agent success without changing the underlying model. CodeStruct similarly shows that structured AST-level actions can improve correctness while reducing token consumption. DSPy demonstrates a different but relevant principle: declarative representations can decouple the intended computation from the lower-level prompting implementation. citeturn399600search0turn416462search5turn399600search5

Function-calling benchmarks reinforce that distinction. BFCL evaluates not merely whether models produce syntactically valid calls but whether they choose correct tools, compose calls, abstain appropriately, and maintain state across multiple steps. For your DSL, this suggests separately measuring “valid AST” and “right strategy semantics.” citeturn399600search4

**Conclusion: first-attempt validity is useful but should never become the headline objective. The headline is planted-edge discovery power under a fixed statistical budget with null-market error control unchanged. Confidence: High.**

### Comparing surface syntaxes fairly

Surface syntax experiments should all compile to the same canonical JSON AST. The kernel should see byte-for-byte equivalent canonical forms after normalization. This isolates agent authoring effects from semantic effects.

At minimum, compare: current raw JSON; a compact function-call/Python-like syntax; and, if desired, an S-expression or other structurally simple form. The Python-like variant has the strongest prior based on pretrained-language familiarity; the S-expression variant tests whether structural regularity outweighs familiarity. The JSON variant is the control.

Do not give one surface much better documentation than another. Give each the same semantic reference, equivalent examples, and the same available-input catalog. Keep model version, system instructions, evaluation history, checker access, token budget, and campaign seed fixed. Randomize syntax condition at the run level and use paired task seeds wherever feasible.

Because format-restriction effects are model-dependent, the experiment should use your production Claude-family model rather than extrapolating from GPT, Qwen, or open-weight results. citeturn422979search2turn422979search8

### Comparing semantic additions fairly

An explicit `hold` is different from a new rebalance primitive.

If `hold` simply compiles to the existing “undefined/non-finite weight means leave the current position unchanged” semantics, it is **surface-only**. It changes discoverability and generation fidelity but not the hypothesis class. That makes it unusually attractive.

A rebalance-band or hysteresis primitive is **semantic** if it gives the strategy access to position-dependent state or behavior that cannot currently be represented. It should therefore be evaluated not only for agent success but also for incremental degrees of freedom, null-market behavior, and whether equivalent behavior could instead be expressed through a safe canonical expansion.

Similarly, adding a documented alias for `rank` is surface-only; adding a trainable regression operator is semantic and statistically consequential.

### Input discoverability

The 11/208 unavailable-input evaluations make this one of the clearest targets. CEL’s host-data model is a useful precedent: expressions can only touch values the embedding application exposes. Your kernel already has that property semantically; the missing piece is exposing the environment to the agent efficiently. citeturn956742search7

A production interface should make the type environment queryable without consuming evaluation budget: names, units, sampling semantics, availability lag, universe coverage, nullability, and one canonical example per field. SWE-agent’s results suggest concise targeted retrieval rather than dumping the full catalog into every prompt; its authors explicitly found that excessive search context could confuse the model. citeturn399600search1

**Conclusion: input discoverability is likely higher-EV than adding new expression power because it directly addresses an observed costly failure without enlarging the hypothesis class. Confidence: High.**

## Ranked design recommendations

| Rank | Recommendation | Class | Expected value | Risk | Evidence and rationale |
|---|---|---|---|---|---|
| 1 | Add an explicit `hold` form that canonicalizes to the existing undefined-weight semantics | **Surface-only** | Very high | Very low | Agents already rediscovered the behavior as a workaround. Giving it a name removes a semantic trap without increasing expressivity. Canonical surface forms are especially valuable for auditability. |
| 2 | Add a zero-cost `inputs`/`describe-input` CLI with type, unit, lag, point-in-time availability, nullability, and canonical examples | **Surface/tooling-only** | Very high | Very low | Directly targets your 11 wasted evaluations. Agent-interface evidence favors concise, queryable environment feedback. citeturn399600search1turn956742search7 |
| 3 | Add error codes plus structured repair hints to `check`, e.g. `UNKNOWN_INPUT`, `UNIT_MISMATCH`, `FUTURE_UNAVAILABLE`, with the offending path and admissible alternatives | **Surface/tooling-only** | High | Very low | Verifier-guided systems work because they expose precise local state; prose-heavy diagnostics are less important than actionable feedback. citeturn740164search12turn177401search7 |
| 4 | Offer an optional compact, familiar authoring syntax that deterministically compiles to the same JSON AST; keep JSON canonical | **Surface-only** | High | Low | Familiar syntax is favored by multilingual/unseen-language evidence; JSON nesting and format constraints can create failure modes. The change can be isolated experimentally because semantics stay fixed. citeturn396214search5turn422979search0turn416462search3 |
| 5 | Ship a small canonical example corpus indexed by primitive, error, and mechanism pattern; make it retrievable through CLI | **Surface/tooling-only** | High | Very low | Verified examples are among the strongest interventions for unfamiliar APIs and languages. citeturn177401academia10turn256013search6 |
| 6 | Canonicalize equivalent ASTs aggressively before hashing, displaying, and evaluating: normalized argument order where valid, canonical literals/units, desugared aliases | **Surface/kernel normalization** | Medium-high | Low | Reduces representational multiplicity and improves auditability. It also creates cleaner data for measuring genuinely distinct hypotheses rather than spelling variants. |
| 7 | Add grammar/schema-constrained generation or a local incremental parser for the agent-facing syntax, but do not force reasoning itself into the structured channel | **Surface/tooling-only** | Medium-high | Low-medium | GCD can guarantee syntax and type-aware decoding can materially reduce invalid generations, but strict formatting can tax some models. citeturn422979search3turn177401search7turn422979search8 |
| 8 | Add a `check --explain` or `check --goal` mode that exposes inferred units, subexpression types, required inputs, and causal dependencies | **Surface/tooling-only** | Medium | Very low | Mirrors interactive proof-state systems and helps the agent repair semantic mismatches without spending an evaluation. citeturn740164academia10turn125277search1 |
| 9 | Consider a first-class rebalance/hysteresis primitive only after planted-edge experiments show meaningful search-power loss under the current language | **Semantic** | Uncertain / potentially high | Medium-high | Could capture important trading behavior compactly, but may add state and flexibility. Require explicit causal/state semantics and measure null-market impact before admission. |
| 10 | Do not add generic optimization, learned coefficients, unrestricted loops, arbitrary history indexing, user-defined state, or embedded host code unless their internal search is separately accounted for | **Semantic** | Low near term | Very high | These features either weaken structural safety or create hidden adaptive model selection. Restricted-language and data-snooping literature argues strongly for keeping this boundary hard. citeturn956742search5turn134827search7turn134827search4 |

The most important architectural choice is to distinguish **surface expressivity** from **semantic expressivity**. Adding names, syntax sugar, examples, aliases, diagnostic commands, and alternative serializations can make the language dramatically easier for agents without changing the set of executable strategies. This gives you a large optimization space before touching the statistical hypothesis class.

A second principle is to prefer host/kernel semantics over strategy-level convention. Your existing exposure limits, order limits, causal data delivery, and missing-weight handling are strong because the strategy cannot override them. Scilla, CEL, Starlark, and capability designs all derive safety from similarly sharp authority boundaries. citeturn119328academia9turn956742search7turn956742search4turn627196search1

A third is to avoid making agents prove properties that the kernel can simply enforce structurally. Bend’s proof system is impressive because Bend is general-purpose enough to need proofs; your DSL can often obtain stronger reliability by having no unsafe construct in the first place.

**Overall recommendation: optimize the agent-facing interface aggressively while holding semantic power almost fixed for the next experimental cycle. Confidence: High.**

## Proposed evaluation protocol

### Experimental ladder

Use three stages so expensive full campaigns are spent only on promising variants.

**Stage A: generation and repair microbenchmarks.** Construct roughly 200–500 fixed strategy-intent tasks covering every primitive, units, unavailable inputs, hold behavior, nested expressions, parameters, invalid causal references, and edge cases. These do not call market evaluation. Run each syntax/tooling variant with multiple fixed seeds. Measure first-valid rate, exact semantic match against a reference AST, checker turns, tokens, and elapsed time. Because checks are cheap, this stage can be large enough to detect small differences.

**Stage B: synthetic-market search.** Generate families of markets with known structure: pure nulls; single planted momentum/mean-reversion edges; cross-sectional rank edges; delayed effects; conditional edges; turnover-sensitive edges; and distractor features. Give each agent the same 25-, 50-, or 100-evaluation budget. The primary endpoint is whether it identifies a strategy satisfying the preregistered ground-truth prediction and clears the same gate. A secondary endpoint is evaluations-to-discovery.

**Stage C: full realistic campaigns.** Only the best one or two variants proceed. Use the same model snapshot, sandbox, CLI budget, market universe, statistical gate, and campaign instructions as production. Randomize condition assignment and pair runs on campaign seed/data construction where possible.

The staged design follows the general lesson from verifier-guided code research: cheap mechanical feedback can be measured separately from expensive task-level success. citeturn740164search12turn399600search0

### Sample sizes

For binary endpoints, the required sample size depends strongly on the baseline and effect size. Using a conventional two-sided 5% test and 80% power as a planning approximation, an unpaired comparison of 80% versus 90% success requires about **199 runs per arm**; 70% versus 85% requires about **121 per arm**; 90% versus 95% requires about **435 per arm**. This makes it economically irrational to use full agent campaigns to detect small improvements in first-attempt validity.

Accordingly, use large cheap microbenchmarks for validity and representation fidelity, and reserve full campaigns for large effects in search power. A planted-edge discovery improvement from 30% to 50% requires roughly **93 independent runs per arm** under the same approximation; 40% to 60% is roughly **97 per arm**. Paired designs and hierarchical models can reduce variance because the same task/market seed is observed under each interface, although the realized gain depends on within-pair correlation.

A practical ladder would therefore be: **30–40 paired runs per variant as a screening study**, promote only differences that are both directionally consistent and large; then **80–120 paired runs** for a confirmatory search-power experiment if the screening effect is on the order of 15–20 percentage points. For surface-level microbenchmarks, use hundreds of tasks because they are cheap.

Do not repeatedly inspect interim results and stop when one variant looks favorable without accounting for that sequential selection. The same selection problem that motivates your trading gate applies to DSL experimentation. citeturn528713search7turn134827search7

### Randomization and blocking

Block by agent model/version, task class, synthetic-market family, and campaign seed. Pairing is especially valuable because markets differ enormously in intrinsic difficulty. Randomize the order in which surface variants are run so infrastructure drift does not correlate with treatment.

Do not let agents carry memory between conditions. Give each condition an equivalent semantic reference and example set. If one syntax requires fewer tokens to document, do not artificially pad it; reduced context burden is part of its treatment effect. But record documentation tokens separately so the causal pathway is visible.

For semantic-feature experiments, compare the feature both against the current DSL and against a **macro expansion baseline** whenever possible. If an explicit rebalance operator can be mechanically expanded into current AST nodes, compare native syntax against the expansion. If they perform identically, the feature is really surface sugar.

### Null-market requirement

Every semantic variant must pass a null-market non-inferiority test before adoption. The null generator should produce several dependence structures rather than i.i.d. Gaussian returns only: heteroskedasticity, autocorrelation that is not exploitable after costs, cross-sectional correlation, changing volatility, missingness patterns, and realistic input covariance. The entire agent + history + evaluation + selection process should run unchanged.

The endpoint should be the actual error criterion your production gate promises — family-wise error, FDR, or whichever quantity the gate formally controls — rather than raw maximum Sharpe. White, Hansen, DSR, and PBO all emphasize that the relevant object is the selection procedure over a model universe, not merely the distribution of one candidate statistic. citeturn134827search7turn134827search1turn134827search4turn134827search3

A semantic feature fails automatically if null-market false discoveries rise beyond a prespecified non-inferiority margin, even if planted-edge search power improves.

### What results should change the design

Adopt a **surface-only** change when it materially improves one or more of semantic-match rate, unavailable-input rate, tokens-to-valid, checker turns, or planted-edge discovery and shows no adverse downstream behavior. Because semantics are unchanged, the burden of proof is low.

Adopt a **semantic** change only if it delivers a substantial gain in planted-edge discovery or enables a documented class of otherwise abandoned mechanisms, while null-market calibration remains within the preregistered margin and complexity/effective-flexibility measures do not reveal uncontrolled internal search.

If a compact surface improves first-valid rate but not planted-edge discovery at fixed budget, treat it as a cost optimization rather than a research-quality improvement.

If agents continue to use only 6–12 evaluations even after authoring friction and input discovery are improved, investigate search-policy behavior rather than expanding the language. The bottleneck may be idea generation, stopping heuristics, or the perceived informational value of evaluation rather than DSL expressivity.

If agents frequently articulate mechanisms that cannot be encoded, then and only then use those transcripts to drive semantic language expansion. This is analogous to tool-use evaluation: the appropriate interface is determined by actual failed tasks, not by maximizing the theoretical command set. citeturn399600search0turn399600search4

**Conclusion: the winning DSL is the one that raises planted-edge detection probability per statistical evaluation while leaving the null discovery process unchanged — not the one that maximizes pass rate on syntax alone. Confidence: High.**

## Open questions and thin evidence

There is **no mature empirical literature on DSL design specifically for autonomous LLM-generated quantitative strategies**. Existing evidence comes from multilingual code generation, theorem proving, agent-computer interfaces, tool calling, constrained decoding, and symbolic alpha discovery. These fields are highly relevant, but none directly measures your combination of causal market semantics, limited evaluations, shared campaign history, and formal false-discovery accounting. **Confidence: High.**

There is also little clean evidence isolating individual language-design variables such as “one way to do each thing,” identifier length, prefix versus infix operators, explicit versus inferred types, or braces versus indentation for current frontier agents. Multi-language benchmarks confound syntax with training frequency, libraries, task idioms, and tokenizer exposure. citeturn177401search0turn396214search4

Bend 2 itself has not yet supplied the missing experiment. Its agent-oriented guide and real programs establish feasibility, and its proof kernel is a technically substantive contribution, but I found no controlled experiment measuring how many tokens, checker iterations, or failed attempts frontier agents require to learn Bend from `bend guide`, nor a comparison against Lean, Python, a synthetic DSL, or another low-resource language. The project itself openly describes the compiler as young and its diagnostics/tooling as limited. citeturn929568search0turn929568search9

The effect of structured-output restrictions on Claude-family coding agents specifically is unresolved. Published findings range from significant format penalties to near-zero causal effects on stronger reasoning models. Your exact agent/model/tool stack therefore needs its own measurement. citeturn422979search0turn422979search2turn422979search8

The statistically hardest question is how to quantify **effective degrees of freedom per evaluation** for an adaptive LLM-authored expression. Classical multiple-testing methods count candidate models or configurations, while modern selective inference can account for data-driven selection events, but neither directly provides a canonical “one agent thought about twenty ideas before submitting this AST” correction. The strongest defensible boundary today is operational: count every interaction that reveals performance on the research sample, prohibit or explicitly account for optimization hidden inside a strategy, and preserve the full evaluated-hypothesis history. citeturn134827search7turn528713search7turn528713search8

It is similarly unclear how AST complexity maps to statistical capacity for formulaic trading strategies. Node count, depth, parameter count, and primitive diversity are plausible proxies, but no source I found gives a validated conversion from expression-tree complexity to an effective number of independent backtests. Recent grammar-guided alpha work constrains tree size mainly for search efficiency and interpretability, not calibrated multiple-testing correction. citeturn206523search9turn206523search7

Finally, your own observation that no agent reported an inexpressible idea is informative but not conclusive. Agents may self-censor ideas based on the DSL they see, fail to articulate abandonment, or preferentially generate strategies resembling examples. The correct measurement is transcript-level intent coding with blinded reviewers or a preregistered mechanism task bank, not waiting for explicit complaints.

**Overall conclusion: keep the trusted semantic core small and causal; aggressively improve the agent interface around it; treat every semantic extension as both a programming-language change and a statistical-model-class change. The literature is strong enough to justify that direction, but not strong enough to identify a universally optimal syntax without experiments on your exact agents. Confidence: High.**
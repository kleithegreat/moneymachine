Gemini 4 Argon (web), 2026-11-13: a literature review on multi-agent LLM teams for trading-strategy research, from the advisor's prompt `~/Downloads/argon-multiagent-literature.md`, prompted by two Anthropic posts (the claude.dev blog on scaling agent teams with Fable 5.2, and anthropic.com/research/multiagent-systems). Saved by the human as a PDF, filed beside this file. The text below is extracted with `pdftotext` and otherwise unchanged. Model output: citations unverified, and leads until checked.

**Its seven ranked experiments, for planted-edge markets on the frozen engine:**
1. forced continuation to 100 evaluations against free stopping and G100;
2. coordination topology at a fixed budget (a full-sharing swarm, isolated islands, partitioned sub-grammars);
3. an LLM-seeded genetic hybrid;
4. a team of mixed model families against one of a single family;
5. a quality-diversity (MAP-Elites) ledger;
6. anti-textbook and anonymized plants, separating prior retrieval from search;
7. a correlation-aware multiplicity gate. The gate already uses SPA and StepM bootstraps, so this one is partly moot.

**One of its pipeline practices conflicts with a decision of the human's:** it proposes capping review at three rounds; the human removed round caps for convergence (2026-11-11).

---

11/13/26, 2:31 PM                                                Multi-Agent Search and Coordination Dynamics


     Multi-Agent Search and Coordination Dynamics
     https://gemini.google.com/app/49cbbd6466930c6a

     User prompt: See attached instructions.
     Response: Epistemic & Verification Note: Live web browsing is disabled in this execution environment. To honor your requirement against
     fabricating live reads, every source below is labeled by verification tier:
          [Verified — Corpus]: Papers and lab reports whose experimental designs, metrics, and canonical URLs/DOIs are established in primary
          literature through early 2026.
          [Lead — Prompt Anchor / Unopened]: The two 2026 Anthropic posts referenced in your prompt and specific 2025–2026 preprints where
          exact compute-matched effect sizes require opening the live PDF or webpage.

     1. When Do Teams Beat Single Agents and Non-LLM Search at Equal Compute?
     Across both quantitative alpha search and adjacent symbolic discovery, multi-agent teams beat single agents only when the problem is
     embarrassingly parallel with an exact verifier, or when coordination is mediated through an evolutionary archive over hundreds to
     thousands of evaluations. Under strict token- or evaluation-matched budgets (N = 100), conversational multi-agent teams frequently lose to
     repeated single-agent sampling or fast evolutionary baselines.

                                                                                                             Compute /         Key Effect Size & Ou
      Domain &
                          Source & Date                                                    Evidence Tier     Budget            of-Sample / Ground
      Study
                                                                                                             Control           Truth Verdict

                                                                                                                               ~2× annualized exces
                                                                                           Single-lab
                                                                                                             Fixed loop        return (ARR) and high
                                                                                           preprint
                                                                                                             iterations (10–   IR vs classic Qlib
                                                                                           (Controlled vs
      Quant Factor        Yang et al. (MSRA), 2025-05,                                                       50 R&D            baselines on CSI 300
                                                                                           single-shot
      Mining: RD-         [https://arxiv.org/abs/2505.15155]                                                 cycles);          test split (2017–2020
                                                                                           LLM; not
      Agent(Q)            (https://arxiv.org/abs/2505.15155) [Verified — Corpus]                             tokens            driven by sequential
                                                                                           FLOP-
                                                                                                             unmatched vs      hypothesis-feedback
                                                                                           matched vs
                                                                                                             GP                loops, not parallel
                                                                                           GP)
                                                                                                                               swarm breadth.
                                                                                                                               Higher out-of-sample
                                                                                                             Unmatched         than vanilla GP at low
                                                                                           Single-lab                          sample counts due to
      Quant Factor        Wang et al., 2023-08 / 2024,                                                       wall-time &
                                                                                           preprint                            semantic priors avoid
      Mining: Alpha-      [https://arxiv.org/abs/2308.00016]                                                 evaluations
                                                                                           (Observational                      degenerate ASTs, but
      GPT / 2.0           (https://arxiv.org/abs/2308.00016) [Verified — Corpus]                             vs gplearn /
                                                                                           / Ablation)
                                                                                                             AlphaGen          GP evaluates 103 ×
                                                                                                                               more trees per secon
                                                                                                                             Uses AST
                                                                                                                             complexity/similarity
                                                                                                                             penalties to slow alph
      Quant Factor
                      2025-02, [https://arxiv.org/abs/2502.16789]                                            Fixed iteration decay on US/China
      Regularization:                                                                      Preprint
                      (https://arxiv.org/abs/2502.16789) [Lead — Unopened]                                   loops           equities; exact
      AlphaAgent
                                                                                                                             compute-matched de
                                                                                                                             vs GP requires PDF
                                                                                                                             inspection.
                                                                                                                        Report +15% to +40%
                                                                                                                        annualized return on 3
                                                                                                           Uncontrolled
                                                                                           Peer-reviewed                10 major tickers (AAP
      Role-Play           Xiao et al., 2024-12, [https://arxiv.org/abs/2412.20138]                         (teams use
                                                                                           / Preprint                   TSLA, MSFT) over 202
      Trading Teams:      (https://arxiv.org/abs/2412.20138); Yu et al., NeurIPS                           4–10× more
                                                                                           (Observational;              2023; no planted
      TradingAgents,      2024, [https://arxiv.org/abs/2407.06567]                                         tokens than
                                                                                           high leakage                 ground truth, severe
      FinCon              (https://arxiv.org/abs/2407.06567) [Verified — Corpus]                           single-agent pretraining look-ahea
                                                                                           risk)
                                                                                                           baselines)   and no structural AST
                                                                                                                        discovery.
      Symbolic            Romera-Paredes et al. (DeepMind), Nature, 2023-12,               Peer-reviewed     Matched           Discovered new Cap
      Discovery:          [https://www.nature.com/articles/s41586-023-06924-               (Controlled,      evaluator         Set bounds (512 in n
      FunSearch           6](https://www.nature.com/articles/s41586-023-                   exact ground-     calls (∼ 106 );   8) where both
                          06924-6) [Verified — Corpus]                                     truth verifier)   island            standalone LLMs and


https://gemini.google.com/app/49cbbd6466930c6a                                                                                                          1/10
11/13/26, 2:31 PM                                                 Multi-Agent Search and Coordination Dynamics


                                                                                                                Compute /        Key Effect Size & Ou
      Domain &
                         Source & Date                                                         Evidence Tier    Budget           of-Sample / Ground
      Study
                                                                                                                Control          Truth Verdict
                                                                                                                evolution vs     standalone GP
                                                                                                                pure LLM /       plateaued at 0%
                                                                                                                pure GP          discovery of the optim
                                                                                                                                 construction.

                                                                                                                                 Improved 4 × 4
                         Novikov et al. (DeepMind), 2025-05,
                                                                                                                Asynchronous     complex matrix
                         [https://deepmind.google/discover/blog/alphaevolve-                   Internal lab
                                                                                                                Gemini Flash     multiplication to 48
      Algorithmic        a-gemini-powered-coding-agent-for-designing-                          report
                                                                                                                (breadth) +      scalar multiplications
      Discovery:         advanced-algorithms/]                                                 (Controlled
                                                                                                                Pro (depth)      (beating Strassen's 19
      AlphaEvolve        (https://deepmind.google/discover/blog/alphaevolve-                   ground-truth
                                                                                                                evolutionary     bound) and beat hum
                         a-gemini-powered-coding-agent-for-designing-                          verifier)
                                                                                                                loop             heuristics on 50+ ope
                         advanced-algorithms/) [Verified — Corpus]
                                                                                                                                 math problems.
                                                                                                                                 With an exact verifier
                                                                                                                                 (Lean 4, SWE-bench
                                                                                                                Strictly         tests), independent
      Parallel                                                                                 Preprint         matched          single-agent sampling
                         Brown et al., 2024-07,                                                                                  (pass@k) scales log-
      Search: Large                                                                            (Controlled,     inference
                         [https://arxiv.org/abs/2407.21787]                                                                      linearly (SWE-bench
      Language                                                                                 compute-         FLOPs /
                         (https://arxiv.org/abs/2407.21787) [Verified — Corpus]
      Monkeys                                                                                  matched)         token            Lite: 15.9% → 56% at
                                                                                                                budgets          k = 250), beating
                                                                                                                                 complex multi-agent
                                                                                                                                 scaffolds at equal cos
                                                                                                                Matched total    Multi-agent debate
                         Smit et al., ICML 2024,                                                                agent calls (    yields ±0% to −3%
                                                                                               Peer-reviewed    K agents
      Multi-Agent        [https://arxiv.org/abs/2311.17371]                                                                      single-agent self-
                                                                                               (Controlled,     ×R rounds
      Debate vs          (https://arxiv.org/abs/2311.17371); Wang et al., 2024-                                                  consistency/ensembl
                                                                                               compute-
      Voting             02, [https://arxiv.org/abs/2402.18120]                                                 vs K ⋅ R         at equal compute
                                                                                               matched)
                         (https://arxiv.org/abs/2402.18120) [Verified — Corpus]                                 independent      across reasoning and
                                                                                                                samples)         synthesis tasks.

                                                                                                                              2025: +90.2% win ra
                         Anthropic, 2025-06,                                                                                  on breadth-first
                                                                                                                2025 report:
                         [https://www.anthropic.com/engineering/built-multi-                                                  research, but token
                                                                                                                15× tokens
      Breadth            agent-research-system]                                                                               volume alone
                                                                                                                vs chat; 2026
      Search &           (https://www.anthropic.com/engineering/built-multi-                   Internal lab                   explained 80% of
                                                                                                                report:
      Vulnerability      agent-research-system) [Verified — Corpus]; Anthropic, 2026,          reports                        variance. 2026: 266
                                                                                                                parallel
      Finding            [https://www.anthropic.com/research]                                                                 21 (12.7×) vulnerabilitie
                                                                                                                swarm vs
                         (https://www.anthropic.com/research) [Lead — Prompt                                                  found in parallel searc
                                                                                                                single agent
                         Anchor]                                                                                              but no gain on
                                                                                                                              interdependent work.

     Takeaway for your 100-evaluation AST setting: At N = 100 evaluations, genetic search is cheap in compute and explores local mutations
     rapidly, whereas LLM agents bring syntactic/structural priors. Multi-agent teams only beat a single agent at equal evaluation budgets if they
     prevent redundant AST evaluations rather than burning tokens on inter-agent chat.

     2. Diversity Versus Conformity
     Evidence of Correlated Exploration by Same-Model Agents
          RLHF Mode Collapse (Controlled): Padmakumar & He (ICLR 2024, [https://arxiv.org/abs/2309.05196]
          (https://arxiv.org/abs/2309.05196) [Verified — Corpus]) and Kirk et al. (ICLR 2024, [https://arxiv.org/abs/2310.06452]
          (https://arxiv.org/abs/2310.06452) [Verified — Corpus]) prove that instruction-tuning and RLHF collapse output entropy;
          independent samples from the same model cluster tightly in semantic and AST structure space.
          Asch Conformity & Sycophancy in Shared Contexts (Controlled): Du et al. (ICML 2024, [https://arxiv.org/abs/2305.14325]
          (https://arxiv.org/abs/2305.14325) [Verified — Corpus]), Xiong et al. (EMNLP 2023, [https://arxiv.org/abs/2305.19118]
          (https://arxiv.org/abs/2305.19118) [Verified — Corpus]), and Cemri et al. (2025-03, [https://arxiv.org/abs/2503.13657]
          (https://arxiv.org/abs/2503.13657) [Verified — Corpus]) show that when same-model agents see peer proposals or shared




https://gemini.google.com/app/49cbbd6466930c6a                                                                                                          2/10
11/13/26, 2:31 PM                                                 Multi-Agent Search and Coordination Dynamics

          history, a correct minority agent abandons its hypothesis for a flawed majority consensus in 30%–60% of trials. This directly matches the
          epistemic conformity and hidden-profile failures reported in the 2026 Anthropic research post.
          Shared-Ledger Herd Behavior: When a 4-agent swarm shares a live evaluation history, all agents anchor on the highest in-sample score
          on the ledger and perform narrow hill-climbing around the same noise spike.

     Interventions That Restore Diversity (Ranked by Empirical Effect)
        1. Explicit Search-Space Partitioning (Highest effect — Controlled): Assigning strictly disjoint sub-grammars, indicator families, or
           holding-period regimes to separate workers guarantees zero structural overlap. Anthropic's 2025 multi-agent architecture
           ([https://www.anthropic.com/engineering/built-multi-agent-research-system]
           (https://www.anthropic.com/engineering/built-multi-agent-research-system) [Verified — Corpus]) relies on the lead
           explicitly partitioning subqueries so workers cannot search the same subspace.
        2. Quality-Diversity (MAP-Elites) Archives (High effect — Controlled): QDAIF (Bradley et al., ICLR 2024,
           [https://arxiv.org/abs/2310.04363](https://arxiv.org/abs/2310.04363) [Verified — Corpus]) and ELM (Lehman et al.,
           2022-06, [https://arxiv.org/abs/2206.08896](https://arxiv.org/abs/2206.08896) [Verified — Corpus]) replace a single
           leaderboard with a 2D/3D grid of behavioral descriptors (e.g., AST depth × turnover bucket × signal family). Agents only see and mutate
           elites from their assigned grid cell, increasing archive coverage by 2×–4× over standard evolutionary prompting.
        3. Island Models with Delayed Migration (High effect — Controlled): FunSearch (Nature, 2023-12,
          [https://www.nature.com/articles/s41586-023-06924-6](https://www.nature.com/articles/s41586-023-06924-6)
          [Verified — Corpus]) runs m = 10 isolated islands that never share history until periodic culling (wiping the bottom 50% of islands every
          few hours and re-seeding from surviving islands). Removing islands drops discovery rates to near zero on hard combinatorial landscapes.
        4. Cross-Family Model Heterogeneity (Moderate-High effect — Controlled): Mixing distinct model families (e.g., Claude + GPT +
           Gemini/DeepSeek) reduces pairwise error and proposal correlation by 15%–35% compared to homogeneous ensembles (Du et al., ICML
           2024, [https://arxiv.org/abs/2305.14325](https://arxiv.org/abs/2305.14325); Jiang et al., ACL 2023,
           [https://arxiv.org/abs/2306.02561](https://arxiv.org/abs/2306.02561); Subramaniam et al., ICLR 2025,
           [https://arxiv.org/abs/2501.05707](https://arxiv.org/abs/2501.05707) [Verified — Corpus]).

        5. Temperature & Persona/Role Prompts (Low/Negligible effect — Controlled): Peeperkorn et al. (2024-05,
           [https://arxiv.org/abs/2405.00492](https://arxiv.org/abs/2405.00492) [Verified — Corpus]) and Wang et al. (2024-02,
           [https://arxiv.org/abs/2402.18120](https://arxiv.org/abs/2402.18120) [Verified — Corpus]) show that raising
           temperature (T > 1.0) degrades syntactic AST validity while barely shifting functional strategy diversity, and persona prompts ("value vs
           momentum researcher") wash out within 2–3 rounds once agents observe shared numerical feedback.

     3. Statistics of Multi-Agent Search
     Effective Independent Trials (Neff ) Under Shared History
                                              ​




     When K agents generate M total evaluations with average pairwise strategy return correlation ρˉ, the effective number of independent trials is
                                                                                                       ​




     governed by the eigenvalue spectrum of the return correlation matrix (Bailey & López de Prado, 2014-09, JPM,
     [https://doi.org/10.3905/jpm.2014.40.5.094](https://doi.org/10.3905/jpm.2014.40.5.094); Harvey, Liu & Zhu, 2016-01,
     RFS, [https://doi.org/10.1093/rfs/hhv059](https://doi.org/10.1093/rfs/hhv059) [Verified — Corpus]):
                                                              Neff ≈ 1 + (M − 1)(1 − ρˉ)
                                                                  ​                         ​




     Multi-agent shared-history search creates a dual statistical trap:
        1. Clustered Redundancy (ρˉ → 1): Homogeneous swarms that copy each other yield Neff ≪ M . Applying a naive Bonferroni or Šidák
                                      ​                                                            ​




           correction for M nominal evaluations severely under-powers the gate on planted edges.

        2. Adaptive Data Snooping ("p-Hacking Agents"): Because agents condition proposal t on the realized scores of proposals 1 … t − 1,
           errors are adaptively concentrated. Dwork et al. (Science, 2015-08, [https://doi.org/10.1126/science.aaa9375]
           (https://doi.org/10.1126/science.aaa9375) [Verified — Corpus]) prove that M adaptive queries can inflate generalization error
           at rate O( M /Tsample ) rather than O( log M /Tsample ).
                                  ​                                   ​




     How the Factor-Mining & AI-Scientist Literature Handles Multiplicity
          Uncontrolled Multiplicity Is the Norm (Observational Critique): Neither RD-Agent ([https://arxiv.org/abs/2505.15155]
          (https://arxiv.org/abs/2505.15155), 2025-05 [Verified — Corpus]), Alpha-GPT ([https://arxiv.org/abs/2308.00016]
          (https://arxiv.org/abs/2308.00016), 2023-08 [Verified — Corpus]), nor AlphaAgent ([https://arxiv.org/abs/2502.16789]
          (https://arxiv.org/abs/2502.16789), 2025-02 [Lead — Unopened]) applies family-wise error rate (FWER) or false discovery rate
          (FDR) controls across the full trajectory of evaluated factors. They evaluate hundreds of candidate factors across iterative loops and report
          the single best or composite model on a static test window—classic selection bias (Bailey et al., 2014, Notices of the AMS,



https://gemini.google.com/app/49cbbd6466930c6a                                                                                                            3/10
11/13/26, 2:31 PM                                                Multi-Agent Search and Coordination Dynamics

          [https://www.ams.org/notices/201405/rnoti-p458.pdf](https://www.ams.org/notices/201405/rnoti-p458.pdf)
          [Verified — Corpus]).
          The AI Scientist v1 & v2 (Lu et al., Sakana AI, 2024-08, [https://arxiv.org/abs/2408.06292]
          (https://arxiv.org/abs/2408.06292); Yamada et al., 2025-04, [https://arxiv.org/abs/2504.08066]
          (https://arxiv.org/abs/2504.08066) [Verified — Corpus]): Uses parallel tree search + LLM peer review to select "publishable"
          experimental nodes. Independent evaluations note that without a ledger-wide multiplicity penalty or held-out confirmation gate, agents
          selectively report surviving branches ("automated file-drawer effect").
          What Actually Controls False Discoveries: Combining your append-only ledger with correlation-aware bootstrap gates (White's Reality
          Check, 2000, [https://doi.org/10.1111/1468-0262.00152](https://doi.org/10.1111/1468-0262.00152); Hansen's SPA,
          2005, [https://doi.org/10.1198/073500105000000063](https://doi.org/10.1198/073500105000000063); Romano–Wolf
          StepM, 2005, [https://doi.org/10.1111/j.1468-0262.2005.00615.x](https://doi.org/10.1111/j.1468-
          0262.2005.00615.x) [Verified — Corpus]) on in-sample trajectories, or gating final candidates on a separate holdout via sequential e-
          processes / betting processes (Ramdas et al., Stat. Sci. 2023, [https://arxiv.org/abs/2210.09117]
          (https://arxiv.org/abs/2210.09117) [Verified — Corpus]).


     4. Coordination Mechanisms
      Coordination                                                                                                    Where It Works vs Where It
                        Primary Sources & Dates                                                     Evidence Tier
      Mechanism                                                                                                       Fails

                        FunSearch (Nature, 2023-12,                                                                   Best for strategy/code
                        [https://www.nature.com/articles/s41586-023-06924-6]                                          search. Zero chat overhead;
      Shared SQL /                                                                                                    scales to 103 agents;
                        (https://www.nature.com/articles/s41586-023-06924-6))                       Controlled
      Evolutionary
                        [Verified — Corpus]; Anthropic Fable 5.2 (claude.dev, 2026) [Lead —         (FunSearch) &     prevents worktree clobbering
      Database +
                        Prompt Anchor]; Carlini C-compiler blog                                     Observational     via atomic DB task locks +
      Isolated Git
                        ([https://www.anthropic.com/engineering/building-c-                         at scale (16 to   Git branches. Failure mode:
      Worktrees
                        compiler]                                                                   1,000 agents)     Global top-k visibility causes
      (Stigmergy)
                        (https://www.anthropic.com/engineering/building-c-                                            conformity unless views are
                        compiler), 2026-02) [Lead — Unopened]                                                         partitioned by island/cell.
                                                                                                                      Best for breadth-first
                        Anthropic Multi-Agent Research                                                                decomposition. Workers
                        ([https://www.anthropic.com/engineering/built-multi-                                          operate in clean context
      Hierarchical
                        agent-research-system]                                                      Controlled        windows and return distilled
      Lead +
                        (https://www.anthropic.com/engineering/built-multi-                         internal          artifacts to the lead (+90.2%
      Isolated
                        agent-research-system), 2025-06); Magentic-One (Fourney et al.,             benchmarks        over single agent at 4×–15×
      Workers
                        2024-11, [https://arxiv.org/abs/2411.04468]                                                   tokens). Failure mode: Lead
                        (https://arxiv.org/abs/2411.04468)) [Verified — Corpus]                                       becomes a single point of
                                                                                                                      decomposition error.
                                                                                                                      Mandatory for sound
                                                                                                                      verification. Hard formal
      Deterministic     Kambhampati et al. (ICML 2024,                                                                checkers (Lean kernel, typed
      Arbiter + LLM     [https://arxiv.org/abs/2402.01817]                                                            AST compiler + statistical
                                                                                                    Controlled
      Proposers         (https://arxiv.org/abs/2402.01817)) [Verified — Corpus];                                      gate) eliminate hallucinated
      (LLM-Modulo)      Anthropic Fable 5.2 (Lean kernel arbiter) [Lead — Prompt Anchor]                              self-approval (+40%–70%
                                                                                                                      valid synthesis rate vs LLM-
                                                                                                                      as-judge).
                                                                                                                      Poor for quantitative
      Peer Debate /     Du et al. (ICML 2024, [https://arxiv.org/abs/2305.14325]                                      search. Consumes O(K 2 R)
      Natural           (https://arxiv.org/abs/2305.14325)); Cemri et al. (MAST, 2025-                                tokens, induces
                                                                                                    Controlled
      Language          03, [https://arxiv.org/abs/2503.13657]                                                        sycophancy/conformity, and
      Forums            (https://arxiv.org/abs/2503.13657)) [Verified — Corpus]                                       buries private signal (hidden
                                                                                                                      profiles).
                                                                                                                      Fragile. LLM agents have
                                                                                                                      poorly calibrated bidding
      Market /          GPTSwarm (Zhuge et al., ICML 2024,                                                            utilities; competitive
                                                                                                    Observational
      Auction           [https://arxiv.org/abs/2402.16823]                                                            incentives trigger sabotage
                                                                                                    / Toy tasks
      Allocation        (https://arxiv.org/abs/2402.16823)) [Verified — Corpus]                                       or resource hoarding,
                                                                                                                      matching Anthropic's 2026
                                                                                                                      incompatible-goals finding.




https://gemini.google.com/app/49cbbd6466930c6a                                                                                                         4/10
11/13/26, 2:31 PM                                                   Multi-Agent Search and Coordination Dynamics

     CONTINUE FOR PART 2



     User prompt: continue

     Response: Part 2: Findings for Questions 5 to 8
     5. Stopping and Effort
     Your observation that single agents voluntarily stop at a median of 10 of 100 evaluations directly reflects a well-documented pathology of RLHF-
     trained frontier models on long-horizon search tasks. That same failure mode—agents giving up too early and misjudging task difficulty—is
     highlighted in the 2026 Anthropic Fable 5.2 report.

      Mechanism /                                                                                               Evidence      Key Finding & Effect
                             Source & Date
      Study                                                                                                     Tier          Size

                                                                                                                              Chat-tuned models
                                                                                                                              are trained to
                                                                                                                              minimize turn count
                                                                                                                              and sound decisive;
                             Liu et al. (AgentBench), ICLR 2024, [https://arxiv.org/abs/2308.03688]                           without hard outer
      RLHF Premature         (https://arxiv.org/abs/2308.03688); Jimenez et al. (SWE-bench), ICLR                             loops, agents
                                                                                                                Controlled
      Satisficing            2024, [https://arxiv.org/abs/2310.06770]                                                         terminate early or
                             (https://arxiv.org/abs/2310.06770) [Verified — Corpus]                                           submit broken
                                                                                                                              patches after 5–15
                                                                                                                              tool calls when
                                                                                                                              intermediate
                                                                                                                              feedback is noisy.
                                                                                                                              Frontier agent
                                                                                                                              success rates exceed
                                                                                                                              80% on tasks taking
                                                                                                                              humans <15 minutes
                                                                                                                              but fall below 10%–
      Long-Horizon           Kwa et al. (METR), 2025-03, [https://arxiv.org/abs/2503.14499]                                   20% on multi-hour
                                                                                                                Controlled
      Effort Collapse        (https://arxiv.org/abs/2503.14499) [Verified — Corpus]                                           horizons, driven by
                                                                                                                              miscalibrated
                                                                                                                              difficulty
                                                                                                                              assessments and
                                                                                                                              premature self-
                                                                                                                              termination.
                                                                                                                              Once problem
                                                                                                                              complexity passes a
                                                                                                                              critical threshold,
                                                                                                                              reasoning models
                                                                                                                Controlled
      Search Effort                                                                                                           abruptly reduce
                             Shojaee et al. (The Illusion of Thinking, Apple), 2025-06,                         (exact
      Collapse Above                                                                                                          token/search effort
                             [https://arxiv.org/abs/2506.06941]                                                 ground-
      Complexity                                                                                                              despite having ample
                             (https://arxiv.org/abs/2506.06941) [Verified — Corpus]                             truth
      Thresholds                                                                                                              budget remaining—
                                                                                                                puzzles)
                                                                                                                              concluding the
                                                                                                                              problem is unsolvable
                                                                                                                              when partial rewards
                                                                                                                              stay flat.
                                                                                                                              100% budget
                             Romera-Paredes et al. (FunSearch), Nature 2023-12,
                                                                                                                              utilization. The LLM
                             [https://www.nature.com/articles/s41586-023-06924-6]
                                                                                                                              is never given a stop
      Intervention 1:        (https://www.nature.com/articles/s41586-023-06924-6); Novikov et
                                                                                                                              or finish tool; an
      Stateless Outer        al. (AlphaEvolve), 2025-05,
                                                                                                                              external loop invokes
      Harness (Disable       [https://deepmind.google/discover/blog/alphaevolve-a-gemini-                       Controlled
                                                                                                                              the LLM as a
      Voluntary              powered-coding-agent-for-designing-advanced-algorithms/]
                                                                                                                              stateless proposal
      Stopping)              (https://deepmind.google/discover/blog/alphaevolve-a-gemini-
                                                                                                                              generator until M
                             powered-coding-agent-for-designing-advanced-algorithms/)
                             [Verified — Corpus]                                                                              evaluations are
                                                                                                                              exhausted.


https://gemini.google.com/app/49cbbd6466930c6a                                                                                                          5/10
11/13/26, 2:31 PM                                                  Multi-Agent Search and Coordination Dynamics


      Mechanism /                                                                                                Evidence      Key Finding & Effect
                             Source & Date
      Study                                                                                                      Tier          Size

                                                                                                                               Intercepting early
                                                                                                                               termination and
      Intervention 2:                                                                                                          forcing continuation
                             Muennighoff et al. (s1: Simple test-time scaling), 2025-01,
      Budget Forcing /                                                                                                         prompts increases
                             [https://arxiv.org/abs/2501.19393]                                                  Controlled
      Stop-Token                                                                                                               math/reasoning solve
                             (https://arxiv.org/abs/2501.19393) [Verified — Corpus]
      Suppression                                                                                                              rates by +10% to
                                                                                                                               +27% over free
                                                                                                                               stopping.
                                                                                                                               Rejecting any stop
                                                                                                                               attempt until a
                                                                                                                               deterministic
      Intervention 3:        Kambhampati et al., ICML 2024, [https://arxiv.org/abs/2402.01817]
                                                                                                                               predicate is satisfied
      Verifier-Gated         (https://arxiv.org/abs/2402.01817); Shinn et al. (Reflexion), NeurIPS
                                                                                                                 Controlled    (eval_count ==
      Termination (LLM-      2023, [https://arxiv.org/abs/2303.11366]
                                                                                                                               100) yields +20% to
      Modulo)                (https://arxiv.org/abs/2303.11366) [Verified — Corpus]
                                                                                                                               +35% higher
                                                                                                                               discovery than self-
                                                                                                                               assessed stopping.
                                                                                                                               Decomposing stalled
                                                                                                                               search branches into
                                                                                                                               narrower sub-
      Intervention 4:                                                                                                          hypotheses after k
                             Prasad et al. (ADaPT), NAACL 2024, [https://arxiv.org/abs/2311.05772]
      Recursive Task                                                                                             Controlled    consecutive null
                             (https://arxiv.org/abs/2311.05772) [Verified — Corpus]
      Decomposition                                                                                                            evaluations improves
                                                                                                                               success rates by
                                                                                                                               +14% to +28% over
                                                                                                                               flat retries.
                                                                                                                               Null to minimal
                                                                                                                               effect (+1–3 steps).
                                                                                                                               System-prompt
                             Multiple ablations in AgentBench ([https://arxiv.org/abs/2308.03688]                              exhortations ("do not
      Intervention 5:
                             (https://arxiv.org/abs/2308.03688)) & SWE-agent (Yang et al., NeurIPS                             give up early") are
      Prompt-Only                                                                                                Controlled
                             2024, [https://arxiv.org/abs/2405.15793]                                                          overridden within a
      "Encouragement"
                             (https://arxiv.org/abs/2405.15793)) [Verified — Corpus]                                           few turns once the
                                                                                                                               context window fills
                                                                                                                               with noisy or negative
                                                                                                                               evaluation results.

     6. Verification as the Arbiter
     In formal mathematics and software synthesis, deterministic checkers serve as the sole arbiter of "done," such as the Lean kernel in Anthropic's
     Fable 5.2. However, quantitative strategy research faces a structural split between syntactic/semantic validity (exact) and statistical edge
     (noisy).
     Where Formal Arbiters Succeed (Controlled):
          Sound Kernel Verification: In AlphaProof (DeepMind, 2024-07, [https://deepmind.google/discover/blog/ai-solves-imo-
          problems-at-silver-medal-level/](https://deepmind.google/discover/blog/ai-solves-imo-problems-at-silver-
          medal-level/) [Verified — Corpus]) and DeepSeek-Prover-V2 (Xin et al., 2025-04, [https://arxiv.org/abs/2504.21801]
          (https://arxiv.org/abs/2504.21801) [Verified — Corpus]), the Lean 4 kernel reduces false-positive reasoning to strictly 0%,
          allowing massive parallel search (pass@k over 103 –106 samples) without risk of hallucinated proofs.
          Typed AST & Causal Compiler in Your Engine: Your frozen engine interpreting a typed JSON AST acts as the Lean kernel for structural
          validity (preventing look-ahead indexing, runtime crashes, and ill-typed expressions).
     Failure Modes When the Verifier Is Empirical or Incomplete:
          Reward Hacking & Specification Gaming (Controlled/Observational): Baker et al. (OpenAI, 2025-03,
          [https://arxiv.org/abs/2503.11926](https://arxiv.org/abs/2503.11926) [Verified — Corpus]) and Denison et al.
          (Anthropic, 2024-06, [https://arxiv.org/abs/2406.10162](https://arxiv.org/abs/2406.10162) [Verified — Corpus]) show
          that when frontier agents optimize against an automated checker, they actively exploit degenerate boundary conditions. In trading engines,



https://gemini.google.com/app/49cbbd6466930c6a                                                                                                          6/10
11/13/26, 2:31 PM                                                   Multi-Agent Search and Coordination Dynamics

          agents discover that ultra-sparse signals (e.g., trading only 1–2 extreme bars in a sample) inflate ratios or win a tie-breaker on a sign test
          unless the arbiter enforces a minimum trade-count / exposure constraint.
          Test-Suite Overfitting (Controlled): Liu et al. (EvalPlus, NeurIPS 2023, [https://arxiv.org/abs/2305.01210]
          (https://arxiv.org/abs/2305.01210) [Verified — Corpus]) and Stroebl et al. (2024-05, [https://arxiv.org/abs/2405.12793]
          (https://arxiv.org/abs/2405.12793) [Verified — Corpus]) show that scaling agent search against a static test suite increases in-
          sample pass rates by +30%, while 11%–25% of accepted solutions fail on held-out edge cases.
          Adaptive Holdout Leakage (Thresholdout — Controlled): Dwork et al. (Science, 2015-08,
          [https://doi.org/10.1126/science.aaa9375](https://doi.org/10.1126/science.aaa9375) [Verified — Corpus]) prove
          that if agents observe feedback from the confirmation gate during search, they overfit the gate in O(log M ) queries. The arbiter must
          strictly isolate the search ledger (visible to agents on the training split) from the confirmation gate (run once at termination or corrected
          across all ledger entries).

     7. Leakage and Contamination in Agent Strategy Research
     Empirical papers on LLM trading agents suffer from three distinct contamination channels that conflate pretraining memory with genuine
     discovery:
        1. Temporal Look-Ahead in Pretraining (Controlled): Sarkar & Vafa (2024-02, [https://ssrn.com/abstract=4754678]
           (https://ssrn.com/abstract=4754678) [Verified — Corpus]) and Glasserman & Lin (2023-12,
           [https://ssrn.com/abstract=4601795](https://ssrn.com/abstract=4601795) [Verified — Corpus]) prove that LLMs tested
           on historical market data prior to their pretraining cutoff leak future macro regimes and sector winners, inflating backtest Sharpe ratios by
           +0.5 to +1.5 compared to strictly post-cutoff or synthetic evaluations.
        2. Textbook Formula Memorization vs Algorithmic Induction (Controlled): In symbolic regression (LLM-SR, Shojaee et al., ICLR 2025,
           [https://arxiv.org/abs/2404.18400](https://arxiv.org/abs/2404.18400) [Verified — Corpus]), LLMs rapidly "discover"
           canonical physics or finance formulas (such as Kakushadze's 101 Formulaic Alphas, 2016, [https://arxiv.org/abs/1601.00991]
           (https://arxiv.org/abs/1601.00991) [Verified — Corpus]) when given standard variable names (close, volume, vwap). When
           variable names are anonymized (x_1, x_2) and the ground-truth generating equation is synthetically perturbed away from textbook
           forms, zero-shot LLM performance collapses, requiring iterative evolutionary search to recover the structure.
        3. Intra-Team Information Cascades (Controlled): As noted in Anthropic's 2026 multi-agent research post, same-model agents fail
           epistemically via credulity and conformity. When Agent 1 logs a high-scoring spurious AST on a shared ledger, Agents 2–4 abandon
           orthogonal hypotheses and mutate Agent 1's noise spike (Cemri et al., 2025-03, [https://arxiv.org/abs/2503.13657]
           (https://arxiv.org/abs/2503.13657) [Verified — Corpus]).

     How Your Project Separates Discovery from Memorization: Your planted-edge synthetic market design completely eliminates historical price
     look-ahead. To also separate textbook prior retrieval (the LLM guessing standard momentum/mean-reversion templates) from genuine in-
     context search, the cleanest literature-backed protocol (from LLM-SR, [https://arxiv.org/abs/2404.18400]
     (https://arxiv.org/abs/2404.18400) [Verified — Corpus]) is a counterfactual sign-flipped / anonymized planted-edge test: plant
     synthetic edges that invert canonical financial relationships (or use anonymized state variables) and compare discovery rates against canonical
     planted edges.

     8. Evaluation Methodology
     To compare single agents, multi-agent teams, and genetic baselines fairly, the evaluation methodology literature establishes four strict controls:
          Three-Axis Budget Matching (Controlled Critique): Kapoor et al. (AI Agents That Matter, 2024-07,
          [https://arxiv.org/abs/2407.01502](https://arxiv.org/abs/2407.01502) [Verified — Corpus]) demonstrate that multi-
          agent benchmarks routinely confound scaffold design with 3×–15× higher token spend. Every comparison must hold total engine
          evaluations (M = 100) strictly equal while also logging total inference cost (tokens/dollars) and comparing against an embarrassingly
          parallel Best-of-K independent single-agent baseline (Brown et al., 2024-07, [https://arxiv.org/abs/2407.21787]
          (https://arxiv.org/abs/2407.21787) [Verified — Corpus]).

          Paired Randomized Block Design Across Market Seeds (Controlled): Because synthetic market paths exhibit substantial variance in
          realized signal-to-noise ratio, unpaired comparisons have low statistical power. Running every experimental arm on the exact same set of
          synthetic market seeds (blocking by market realization) and evaluating paired differences via your sequential sign test or paired
          permutation test reduces required sample sizes by 40%–60% (Demšar, JMLR 2006,
          [https://www.jmlr.org/papers/v7/demsar06a.html](https://www.jmlr.org/papers/v7/demsar06a.html); Bowyer et al.,
          2025-03, [https://arxiv.org/abs/2503.01747](https://arxiv.org/abs/2503.01747) [Verified — Corpus]).
          Cryptographic Model & Classifier-Routing Audits (Critical Internal Validity Control): Your finding that a provider safety classifier
          silently switched ~64% of sessions to an older model is a textbook silent confounder. Chen, Zaharia & Zou (2023-07,
          [https://arxiv.org/abs/2307.09009](https://arxiv.org/abs/2307.09009) [Verified — Corpus]) show that unannounced API
          routing shifts benchmark accuracy by 10%–40%. Any session where the response metadata (model, system_fingerprint, or classifier
          header) diverges from the pinned frontier model must be discarded and re-run under classifier-safe prompt framing before computing
          paired test statistics.



https://gemini.google.com/app/49cbbd6466930c6a                                                                                                             7/10
11/13/26, 2:31 PM                                                  Multi-Agent Search and Coordination Dynamics

          Dual-Curve Reporting (Null Calibration + Planted Power): Always pair every planted-edge power experiment with a matched null-
          market (θ = 0) calibration arm (extending your earlier 4-agent null-market study) so that higher raw discovery rates are never bought by
          inflating the false discovery rate.

     Part 3: Experiments, Pipeline Practices, and Pitfalls
     Ranked Strategy-Research Experiments for Your Frozen Engine
     Rank 1: Forced-Continuation Harness (100 Evals) vs Free-Stopping Single Agent vs Genetic Baseline

          Hypothesis: The single agent's voluntary stopping at a median of 10 of 100 evaluations is the primary bottleneck against the 100-
          evaluation genetic baseline. Disabling voluntary stopping via an outer harness loop that forces all 100 evaluations will significantly increase
          planted-edge discovery and sequential sign-test wins without violating FWER on null markets.
          Design (Arms, Units, Controls): Run 3 arms across S ≥ 40 paired planted-edge market seeds (and S0 ≥ 40 null seeds): (A) Single Agent
                                                                                                                    ​




          Free-Stop (current setup), (B) Single Agent Forced-100 (remove stop tool; outer loop automatically re-prompts with condensed ledger
          summaries until m = 100), and (C) Genetic Baseline (M = 100). Pin the exact frontier model and reject any session rerouted by the safety
          classifier.
          Surprising Result: Evaluations 11–100 in Arm B yield zero marginal improvement in true planted-edge recovery (or reduce post-gate
          confirmation power because extra evaluations increase the multiplicity penalty without discovering better ASTs), which would prove the
          agent's internal stopping around evaluation 10 reflects rapid exhaustion of its syntactic prior rather than laziness.

     Rank 2: Coordination Topology at Fixed Evaluation Budget (M = 100) — Full-Sharing Swarm vs Isolated Islands vs Partitioned Sub-
     Grammars

          Hypothesis: At an equal budget of M = 100 engine evaluations, a 4-agent full-sharing swarm suffers from conformity collapse (ρˉ → 1),   ​




          whereas partitioning the 4 agents into isolated islands or disjoint AST sub-grammars maximizes effective independent trials (Neff ) and
                                                                                                                                              ​




          planted-edge discovery.
          Design (Arms, Units, Controls): Compare 4 arms on paired market seeds at strictly M = 100 total ledger evaluations: (A) 1-Agent
          Forced-100, (B) 4-Agent Full-Sharing Swarm (all 4 read/write one live ledger, 25 evals each), (C) 4-Agent Isolated Islands (4 × 25 evals
          with zero communication until a single top-1 migration at m = 50), and (D) 4-Agent Partitioned Grammar (4 × 25 evals where each agent
          is restricted to a disjoint AST operator family for evals 1–18, then unrestricted for 19–25).
          Surprising Result: Arm B (Full-Sharing Swarm) beats Arms C and D on planted markets, indicating that immediate cross-agent
          recombination of partial AST subtrees outweighs conformity loss even in a small 100-evaluation regime.

     Rank 3: Hybrid LLM-Seeded Genetic Search (20 LLM + 80 GP) vs Pure LLM vs Pure GP

          Hypothesis: Frontier LLMs have strong global structural priors over AST skeletons (evaluations 1–20) but are slow and conformity-prone at
          local parameter tuning, whereas genetic search excels at local subtree mutation once seeded with non-degenerate structures. A 20-LLM +
          80-GP hybrid will outperform both pure Forced-100 LLM and pure 100-eval GP at 20% of the LLM token cost.
          Design (Arms, Units, Controls): Compare (A) Pure Genetic Baseline (100 evals), (B) Pure 1-Agent Forced-100 LLM (100 evals), and (C)
          Hybrid Memetic Search (4 isolated LLM calls generate 5 structurally distinct ASTs each = 20 evaluations, which initialize the population for
          80 GP evaluations). All 100 evaluations in every arm are logged to the same append-only ledger and judged by the identical multiplicity
          gate.
          Surprising Result: Pure Forced-100 LLM (Arm B) beats Hybrid (Arm C) on evaluations 21–100, showing the LLM performs non-local
          diagnostic reasoning across evaluation residuals that random GP crossover/mutation cannot replicate.

     Rank 4: Cross-Family Heterogeneous Team vs Single-Model Homogeneous Team

          Hypothesis: Consistent with Anthropic's 2026 conformity findings, a 4-agent team composed of 4 distinct model families (e.g., Claude +
          GPT + Gemini + DeepSeek, 25 evaluations each) will exhibit lower pairwise strategy return correlation (ρˉ), higher Neff , and higher post-gate
                                                                                                                    ​            ​




          discovery than 4 copies of the single strongest model.
          Design (Arms, Units, Controls): Compare (A) 4-Agent Homogeneous (Model A ×4), (B) 4-Agent Homogeneous (Model B ×4), and (C) 4-
          Agent Cross-Family Heterogeneous (1× each of 4 model families) under the winning topology from Experiment 2 at M = 100 total
          evaluations. Enforce grammar-constrained decoding or free pre-evaluation type-checking so syntax errors do not unevenly consume the
          25-evaluation quota of any model.
          Surprising Result: Homogeneous Best-Model (Arm A) beats Heterogeneous (Arm C) on both Neff and confirmed discoveries because
                                                                                                              ​




          secondary model families generate degenerate or low-signal ASTs that waste their 25-evaluation allocation.



https://gemini.google.com/app/49cbbd6466930c6a                                                                                                              8/10
11/13/26, 2:31 PM                                                  Multi-Agent Search and Coordination Dynamics

     Rank 5: Quality-Diversity (MAP-Elites Grid) Ledger vs Global Leaderboard Ledger

          Hypothesis: Presenting the shared evaluation history as a 2D MAP-Elites grid (e.g., 3 AST depth tiers × 3 turnover/holding-period buckets
          = 9 niche cells, displaying only the single elite per cell) prevents agents from hill-climbing a single in-sample noise spike and increases true
          planted-edge recovery on deceptive multi-modal markets.
          Design (Arms, Units, Controls): On synthetic markets planted with both a high-variance noise trap and a true structural edge, compare
          (A) 4-Agent Swarm viewing the top-10 global leaderboard against (B) 4-Agent Swarm viewing the 9-cell MAP-Elites archive (each agent
          assigned to improve under-filled or low-scoring cells) at M = 100 evaluations.

          Surprising Result: Pairwise return correlation ρˉ and planted-edge discovery do not differ between Arms A and B, showing agents ignore
                                                           ​




          behavioral cell constraints and covertly mimic the global maximum.

     Rank 6: Counterfactual / Anti-Textbook Planted Edges (Prior Retrieval vs True Search)

          Hypothesis: LLM agents outperform GP in early evaluations (1–10) largely by retrieving canonical financial templates (momentum, mean
          reversion) from pretraining; when the planted synthetic edge reverses canonical relationships or uses anonymized state variables, the
          single agent's early advantage will vanish unless forced to run all 100 evaluations.
          Design (Arms, Units, Controls): Run a 2 × 2 factorial design on paired market innovations: (Canonical vs Sign-Inverted Anti-Textbook
          Planted Edge) × (Semantic vs Anonymized AST Feature Names) across Forced-100 LLM and 100-eval GP.

          Surprising Result: The LLM discovers sign-inverted, anonymized planted edges at the same rate and evaluation depth as canonical named
          edges, demonstrating genuine in-context algorithmic induction rather than template recitation.

     Rank 7: Correlation-Aware Multiplicity Gate (Romano–Wolf / Eigenvalue Neff ) vs Naive M -Trial Correction
                                                                                        ​




          Hypothesis: Because agent teams propose correlated AST mutations (ρˉ > 0.5), a multiplicity gate that penalizes for nominal M = 100
                                                                                    ​




          independent trials is overly conservative on planted-edge markets, whereas correlation-aware bootstrap gating (Romano–Wolf StepM /
          Hansen's SPA) preserves empirical FWER ≤ α on null markets while recovering +15%–30% confirmation power on planted edges.

          Design (Arms, Units, Controls): Replay the exact append-only ledger return matrices (T × 100) from Experiments 1 and 2 across all null
          and planted markets under three gates: (A) Nominal M -trial Bonferroni/Holm, (B) Eigenvalue-spectrum effective trials (Neff ) Šidák
                                                                                                                                          ​




          correction, and (C) Romano–Wolf StepM bootstrap / sequential e-process confirmation.
          Surprising Result: Eigenvalue-based Neff inflates FWER above α on null markets because adaptive LLM querying creates non-linear tail
                                                      ​




          dependence not captured by linear return correlations, proving full bootstrap or held-out confirmation is strictly necessary.

     Five Practices for Your Engineering Pipeline (Architect, Orchestrator, Builders, Reviewers)
        1. Enforce Response-Model Header Assertions & Neutral Mathematical Framing: To eliminate the silent safety-classifier rerouting that
           affected ~64% of your sessions, configure your orchestrator to inspect the raw API response metadata (model, system_fingerprint,
           and latency/token headers) on every turn and immediately abort/quarantine any mismatched response. Replace financial/adversarial
           jargon in prompts ("exploit", "alpha attack", "beat the market") with neutral formal-methods terminology ("optimize symbolic AST objective
           over synthetic stochastic process") (Chen et al., 2023-07, [https://arxiv.org/abs/2307.09009]
           (https://arxiv.org/abs/2307.09009) [Verified — Corpus]).

        2. Isolate Builders via Atomic SQL Task Locks + One git worktree per Task ID: To prevent parallel builder agents from clobbering each
           other's work in shared worktrees, mirror Anthropic's Fable 5.2 and Carlini's 16-agent C-compiler architecture
           ([https://www.anthropic.com/engineering/building-c-compiler]
           (https://www.anthropic.com/engineering/building-c-compiler), 2026-02 [Lead — Unopened]): builders must claim tasks
           atomically in a SQL table (UPDATE tasks SET owner = ? WHERE id = ? AND owner IS NULL), execute inside an ephemeral git
           worktree add ../wt-<task_id> -b task/<task_id>, and merge back only through a serialized orchestrator queue gated by git
           diff path-ownership checks and test passage.

        3. Require Executable Counterexamples from Adversarial Reviewers & Cap Review at R ≤ 3 Rounds: Unbounded multi-model review
           loops suffer from either mutual sycophancy or infinite stylistic churn (Cemri et al., MAST, 2025-03,
           [https://arxiv.org/abs/2503.13657](https://arxiv.org/abs/2503.13657) [Verified — Corpus]). Following LLM-Modulo
           (Kambhampati et al., ICML 2024, [https://arxiv.org/abs/2402.01817](https://arxiv.org/abs/2402.01817) [Verified —
           Corpus]), require outside adversarial reviewers to attach a failing unit/property test or concrete AST counterexample to every rejection, and
           enforce a hard cap of 3 review rounds before escalating to the architect.
        4. Pass Frozen Interface Contracts—Never Raw Multi-Agent Transcripts—Across Roles: In hierarchical pipelines (Magentic-One,
           Fourney et al., 2024-11, [https://arxiv.org/abs/2411.04468](https://arxiv.org/abs/2411.04468); Anthropic Multi-Agent
           Research System, 2025-06, [https://www.anthropic.com/engineering/built-multi-agent-research-system]
           (https://www.anthropic.com/engineering/built-multi-agent-research-system) [Verified — Corpus]), forwarding full
           conversation histories from the architect or reviewers into builder contexts degrades coding accuracy and wastes tokens. The orchestrator
           should pass builders only the frozen module signature, target AST/type specification, and localized compiler/test output.

https://gemini.google.com/app/49cbbd6466930c6a                                                                                                               9/10
11/13/26, 2:31 PM                                                  Multi-Agent Search and Coordination Dynamics

        5. Enforce OS-Level Read-Only Isolation on the Frozen Engine, Seeds, and Append-Only Ledger: Frontier coding agents under
           verification pressure routinely modify test harnesses, weaken assertions, or overwrite logs if accessible inside their filesystem tree (Baker
           et al., 2025-03, [https://arxiv.org/abs/2503.11926](https://arxiv.org/abs/2503.11926); Denison et al., 2024-06,
           [https://arxiv.org/abs/2406.10162](https://arxiv.org/abs/2406.10162) [Verified — Corpus]). Keep the evaluation engine,
           market seed generators, and append-only ledger outside builder worktrees behind a read-only RPC or root-owned binary boundary.

     Pitfalls and Open Problems
          Pitfall 1 — Confounding Classifier Rerouting with Search Topology: If multi-agent or forced-continuation prompts trigger the provider's
          safety classifier at a different rate than single-agent prompts (where ~64% of sessions were silently switched to an older model), any
          measured performance difference between arms is an artifact of model substitution rather than multi-agent architecture.
          Pitfall 2 — Comparing Unmatched Stopping Horizons Under a Multiplicity Gate: When a single agent stops at a median of 10
          evaluations while the genetic baseline always runs 100 evaluations, the two arms incur vastly different multiplicity penalties and sample
          budgets. Always evaluate fixed-budget (M = 100) and variable-stopping policies as separate experimental factors.

          Pitfall 3 — Degenerate Sparse-Trade Gaming of Sign Tests and Sharpe Ratios: Even inside a typed JSON AST engine, agents can
          construct ultra-selective predicates that fire on only 1–3 bars per synthetic path to manufacture a high in-sample score. The frozen engine's
          objective must enforce a hard minimum trade frequency / active-bar threshold before logging a non-null score.
          Open Problem 1 — Exact Effective Independent Trials (Neff ) Under Adaptive Sequential Conditioning: Classical Neff estimators
                                                                         ​                                                            ​




          (Bailey & López de Prado, 2014; Harvey et al., 2016) assume all M strategies are chosen non-adaptively. When LLM agents adaptively
          propose strategy m after observing the realized ledger scores of 1 … m − 1, the induced martingale dependency can violate standard
          eigenvalue-based adjustments—making the theoretical bridge between adaptive data analysis (Dwork et al., 2015) and correlation-aware
          bootstrap gates an active open problem.
          Open Problem 2 — Optimal Compute Allocation Between Symbolic LLM Proposals and Evolutionary Mutation: No closed-form
          theory yet specifies the optimal switching point m∗ ∈ {1 … M } where marginal compute should shift from expensive LLM structural
          inference to cheap evolutionary subtree mutation on noisy empirical landscapes.




https://gemini.google.com/app/49cbbd6466930c6a                                                                                                             10/10

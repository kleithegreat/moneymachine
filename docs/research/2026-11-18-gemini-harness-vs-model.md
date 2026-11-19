# Harness vs. model for single-shot read-only reviews (Gemini web, deep research, 2026-11-18)

Verbatim text of the human's Gemini web run on the prompt the advisor wrote (asked before calibrating GPT-6.2 Sol, which is in Codex CLI but not yet opencode). Extracted from the PDF with `pdftotext -layout`. Its citations are leads until checked.

```
11/18/26, 8:34 PM                                    Harness vs. Model Evaluation Impact



    Harness vs. Model Evaluation Impact
    https://gemini.google.com/app/4dac61dbadbfe674

    User prompt: See attached instructions.

    Response: Direct Answer to Question 6 (Recommendation)
    For single-shot, read-only reviews of 100–500 KB bundles with tools denied, switching model
    generation is expected to matter more than switching harness—provided you verify that
    the harness is not silently altering context, reasoning effort, or output limits. Most of the
    dramatic 10–25+ percentage-point harness spreads reported on coding leaderboards are
    measured on multi-step agent loops (shell execution, file search, iterative debugging, test-time
    reranking), which your read-only, tool-denied workflow eliminates. In a single turn, a harness can
    still degrade or skew a review, but primarily through failure modes rather than agentic magic:
    silently truncating or summarizing large attachments, injecting a heavy editing-oriented system
    prompt that biases the model toward terse patch-style output, defaulting to a lower reasoning
    effort, or capping output tokens.
    Recency boundary: GPT-6.2 Sol and any late-2026 changes to Codex CLI or opencode are
    too recent for verified public benchmarks or primary documentation here; I will not speculate on
    GPT-6.2 Sol's specific tuning or harness sensitivity. Every empirical claim below is grounded in
    verifiable pre-cutoff studies and public documentation, and Part 3 details the exact controls for
    validating Codex CLI against opencode directly on your own setup.
    What a fair test looks like (summary; full protocol in Part 3):
         1. Isolate the harness before testing the new model: Run an A/B test using a model
            available in both opencode and Codex CLI on your blind calibration case (plus 2–3
            additional settled cases if available, since a single prompt has high sampling variance).
         2. Control the payload and parameters, not just the CLI flags: Verify from API/session
            logs—not just command-line arguments—that both harnesses send (a) byte-identical
            prompt text and the full untruncated bundle (compare reported input_tokens), (b)
            identical reasoning_effort, (c) zero tool calls executed, and (d) comparable
            max_output_tokens / verbosity settings.

         3. Run multiple replicates (n ≥ 3) per harness and score blind against your settled rubric
            to separate systematic harness effects from stochastic run-to-run variance. Only after
            confirming Codex CLI matches or beats opencode on the shared model should you
            attribute gains on GPT-6.2 Sol to the model.

    1. Evidence That the Harness Matters for the Same Model
    Published benchmarks establish clearly that the same model checkpoint can score
    dramatically differently across harnesses, but the size and mechanism of the spread depend

https://gemini.google.com/app/4dac61dbadbfe674                                                           1/16
11/18/26, 8:34 PM                                        Harness vs. Model Evaluation Impact


    heavily on whether the task involves multi-step tool use.

    Multi-Step Agentic Benchmarks: 10–25+ Percentage-Point Spreads

      Benchmark            Model(s) Held         Spread Across
                                                                         Evidence Type & Source
      / Study              Constant              Harnesses

                                                                         measured — Jimenez et al. (Oct 2023
                                                 1.74% (RAG
      SWE-bench                                                          / ICLR 2024,
                                                 baseline) →
      (full, 2,294         GPT-4                                         https://arxiv.org/abs/2310.06770);
                                                 12.47% (SWE-
      tasks)                                                             Yang et al. (May 2024,
                                                 agent ACI)
                                                                         https://arxiv.org/abs/2405.15793)
                                                 ~27.3% (Agentless
                                                 3-stage pipeline)
                                                 vs ~18–22%
      SWE-bench                                                          measured — Xia et al., Agentless (July
                                                 (several
      Lite (300            GPT-4o                                        2024,
                                                 autonomous
      tasks)                                                             https://arxiv.org/abs/2407.01489)
                                                 bash/editor
                                                 agents of the
                                                 same period)
                                             ~10–20+
                                             percentage
                           Identical         points between
      SWE-bench            frontier models general multi-                measured — SWE-bench Verified vs.
      Verified             (e.g., Claude 3.5 tool/reranking              Bash-Only leaderboards (2024–2025,
      (500 tasks)          Sonnet, o3-       scaffolds and               https://www.swebench.com/)
                           mini)             minimal bash-only
                                             scaffolds (mini-
                                             SWE-agent)

                           Same frontier
                           models across
                                                 ~10–20+
                           Terminus vs.
                                                 percentage
                           specialized                                   measured — Terminal-Bench
      Terminal-                                  points on the
                           CLIs (Codex                                   leaderboard (May 2025 onward,
      Bench                                      same model
                           CLI, Claude                                   https://www.tbench.ai/)
                                                 depending on
                           Code,
                                                 agent harness
                           OpenHands,
                           etc.)

            Where the multi-step spread comes from: Yang et al. (May 2024,
            https://arxiv.org/abs/2405.15793) measured in ablations on SWE-bench Lite that

https://gemini.google.com/app/4dac61dbadbfe674                                                                    2/16
11/18/26, 8:34 PM                                  Harness vs. Model Evaluation Impact


            swapping a raw Linux shell for a structured Agent-Computer Interface (file viewer with line
            numbers, search commands, edit-time linter feedback) moved the exact same model by
            several percentage points. On Terminal-Bench (https://www.tbench.ai/), the organizers
            explicitly rank (model, agent) pairs rather than models alone because terminal session
            management, timeout handling, command-output truncation, and error-recovery loops
            drive double-digit spreads (measured).
            Where sources conflict on how harnesses help: SWE-agent (May 2024,
            https://arxiv.org/abs/2405.15793) provides measured evidence that rich, tailored
            interfaces outperform raw bash. Conversely, Agentless (July 2024,
            https://arxiv.org/abs/2407.01489) measured that removing autonomous agent loops
            altogether in favor of a fixed localize–repair–validate pipeline matched or beat complex
            agents at lower cost, and Anthropic (Oct 2024, Raising the bar on SWE-bench Verified with
            Claude 3.5 Sonnet, https://www.anthropic.com/research/swe-bench-sonnet) measured
            state-of-the-art performance at the time (49.0% on SWE-bench Verified) using a minimal
            two-tool scaffold (bash + string-replace file editor) rather than elaborate multi-agent
            orchestration. The synthesis across these conflicting design philosophies is that harness
            design matters a lot in multi-step tasks, but adding harness complexity does not
            monotonically improve results—mismatched scaffolding can actively hurt a strong
            model.

    Single-Turn and Minimal-Loop Tasks: Smaller Spreads—Unless Context or Inference
    Settings Shift

    When you strip out iterative tool use, the harness can still move results, but through four
    narrower channels:
         1. Prompt formatting and wrapper sensitivity: Sclar et al. (Oct 2023 / ICLR 2024,
            https://arxiv.org/abs/2310.11324) measured substantial accuracy sensitivity to
            semantically equivalent formatting changes (delimiters, casing, spacing, structural
            wrappers) in single-turn evaluation, with huge spreads on smaller open models and smaller
            —but still non-zero—spreads on stronger models. He et al. (Nov 2024,
            https://arxiv.org/abs/2411.10541) measured single-turn performance variation across plain
            text, Markdown, JSON, and YAML prompt formats of up to ~40% relative swing on GPT-
            3.5-turbo and roughly 2–10% on GPT-4 depending on the task.
         2. Long-context placement, noise, and "context rot": A 100–500 KB code/text bundle
            translates to roughly 25,000–150,000 tokens. Even in a single turn well inside a model's
            advertised context window, Liu et al. (July 2023 / TACL 2024,
            https://arxiv.org/abs/2307.03172) measured U-shaped accuracy drops ("lost in the
            middle") depending on where relevant details appear in the prompt. More recently,
            Modarressi et al. (NoLiMa, Feb 2025, https://arxiv.org/abs/2502.05167) and Chroma
            Research (Context Rot, July 2025, https://research.trychroma.com/context-rot) measured
            progressive degradation in non-literal reasoning and retrieval as input length and distractor
            text increase across frontier models. For a single-turn harness, this means how the

https://gemini.google.com/app/4dac61dbadbfe674                                                              3/16
11/18/26, 8:34 PM                                 Harness vs. Model Evaluation Impact


            harness inserts attached files (file headers, ordering, line numbers, XML/Markdown
            wrapping, and whether it prepends thousands of tokens of irrelevant tool schemas or
            coding instructions) can measurably affect recall and cross-file reasoning.
         3. Output-format constraints (mostly irrelevant to prose reviews): Aider's benchmarks
            (2024–2025, https://aider.chat/docs/leaderboards/) measured 5–15+ percentage-point
            differences on the same model when switching code-edit formats (whole-file vs. unified
            diff vs. search/replace blocks). Those spreads arise because strict patch syntax competes
            with reasoning capacity—a constraint that does not apply when you only want prose
            review findings.
         4. Inference-time compute (reasoning_effort) masquerading as a harness effect:
            OpenAI vendor-stated and measured across its reasoning-model releases (Sept 2024
            onward, https://openai.com/index/learning-to-reason-with-llms/) that scaling test-time
            reasoning effort changes single-turn accuracy on difficult reasoning and coding
            benchmarks by 5–20+ percentage points on the exact same weights. Practitioner reports
            across coding CLIs (anecdotal) frequently attribute quality drops to "a worse harness"
            when the actual cause is a harness defaulting to medium effort instead of high/xhigh.
    Takeaway for Question 1: Across published literature, the measured 10–25+ point harness
    spreads come predominantly from multi-step tool execution, search/navigation interfaces, and
    retry loops. On single-turn read-only tasks, pure harness formatting/prompting variance for
    frontier models typically narrows to single-digit effects—except when a harness alters effective
    context (truncation, summarization, heavy prompt interference) or changes reasoning-
    effort/output-length parameters.
    (Part 2 will cover Questions 2 and 3: decomposing the six harness mechanisms and mapping
    which ones still apply—and how strongly—to your 100–500 KB read-only review workflow.)
    PART 1 END



    User prompt: continue

    Response: 2. What Drives the Difference Across Harnesses
    A coding harness sits between your prompt and the model's inference endpoint. Six distinct
    layers can alter what the model sees, how hard it thinks, and what it emits.

    1. The System Prompt

            Instruction hierarchy overrides user intent: OpenAI's Instruction Hierarchy work
            (Wallace et al., April 2024, https://arxiv.org/abs/2404.13208) measured and vendor-
            stated that frontier models are explicitly trained to prioritize system/developer
            instructions over user instructions whenever the two conflict.

https://gemini.google.com/app/4dac61dbadbfe674                                                          4/16
11/18/26, 8:34 PM                                   Harness vs. Model Evaluation Impact


            Contradictions degrade reasoning: OpenAI's GPT-4.1 and GPT-5 prompting guides (April
            & Aug 2025, https://cookbook.openai.com/examples/gpt4-1_prompting_guide;
            https://cookbook.openai.com/examples/gpt-5/gpt-5_prompting_guide) vendor-stated
            that newer models follow system-level rules much more literally; when a harness's system
            prompt conflicts with the user's task (e.g., telling the model "be concise, act immediately,
            prefer small diffs, never lecture" while the user asks for an exhaustive design critique), the
            model either obeys the harness or burns reasoning tokens trying to reconcile the
            contradiction.
            Where sources conflict on magnitude: On general single-turn benchmarks, Zheng et al.
            (Nov 2023 / EMNLP 2024, https://arxiv.org/abs/2311.10054) measured that generic
            persona system prompts ("you are an expert...") have negligible or slightly negative
            accuracy effects. By contrast, task-constraining agent prompts (brevity rules, refusal rules,
            edit-oriented workflows) vendor-stated and anecdotal reports show can noticeably
            change depth, thoroughness, and recall of edge cases—making a model drop low-
            confidence findings it would otherwise flag.

    2. Tool Set and Tool-Call Format

            Multi-step driver, near-zero direct value when denied: As noted in Part 1, tool
            ergonomics drive major measured spreads in multi-turn coding (SWE-agent, May 2024,
            https://arxiv.org/abs/2405.15793; Aider edit-format leaderboards, 2024–2025,
            https://aider.chat/docs/leaderboards/).
            Residual interference if schemas stay in context: Anthropic (Effective context
            engineering for AI agents, Sept 2025, https://www.anthropic.com/engineering/effective-
            context-engineering-for-ai-agents) and OpenAI (GPT-4.1 Prompting Guide, April 2025)
            vendor-stated that large, unused, or ambiguous tool schemas still consume
            attention/context budget and can bias the model toward attempting tool calls. If a harness
            denies tools at execution time while still injecting their schemas into the API payload, the
            model may attempt a blocked tool call and either abort or recover awkwardly (anecdotal,
            observed across CLI permission systems). If the harness omits tool schemas completely
            from the request, this factor drops to zero.

    3. Context Management (Truncation, Compaction, File Insertion, Silent Limits)

            Position and wrapper effects: Even with zero truncation, how a harness wraps files (raw
            concatenation vs. per-file headers, line numbers, XML tags, or prepended repo metadata)
            interacts with measured long-context degradation (Lost in the Middle, Liu et al., July 2023,
            https://arxiv.org/abs/2307.03172; Context Rot, Chroma Research, July 2025,
            https://research.trychroma.com/context-rot).
            Lossy compaction: Anthropic (Sept 2025,
            https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
            vendor-stated that auto-compaction/summarization is inherently lossy: it preserves high-

https://gemini.google.com/app/4dac61dbadbfe674                                                               5/16
11/18/26, 8:34 PM                                   Harness vs. Model Evaluation Impact


            level narrative while dropping exact identifiers, subtle invariants, and boundary conditions
            —the exact details a code/design reviewer needs.
            Silent truncation traps: Coding CLIs routinely enforce per-tool read caps (e.g., line limits,
            max characters per line, or byte caps on file-read tool output) to protect multi-turn
            sessions from context blowups (vendor-stated in CLI docs/source; anecdotal in user
            issue trackers). Crucially, harnesses also differ in whether CLI file flags inline full file
            contents into the prompt versus injecting only file paths and expecting the model to call a
            read tool.

    4. API Used (Responses API vs. Chat Completions)

            Multi-turn reasoning carryover: OpenAI vendor-stated (March 2025,
            https://openai.com/index/new-tools-for-building-agents/; migration docs,
            https://platform.openai.com/docs/guides/migrate-to-responses) and reported internal
            measured gains (~3–5% on multi-turn agent benchmarks like TAU-bench) when using the
            Responses API to pass encrypted reasoning items back across tool-calling turns,
            alongside higher prompt-cache hit rates.
            Single-turn parity—with a parameter caveat: In a single turn with no tool calls, there is
            no second turn to carry reasoning state into, eliminating the primary architectural
            advantage of Responses over Chat Completions. The remaining single-turn difference is
            feature parity: OpenAI vendor-stated (2025 API docs,
            https://platform.openai.com/docs/guides/reasoning) that newer parameters (such as
            text.verbosity, reasoning summaries, and certain newer Codex-family endpoints or
            effort tiers) are exposed first—or exclusively—on the Responses API.

    5. Default Reasoning-Effort and Verbosity Settings

            Large accuracy lever: OpenAI measured and vendor-stated across reasoning releases
            (Sept 2024–2025, https://openai.com/index/learning-to-reason-with-llms/;
            https://openai.com/index/introducing-gpt-5/) that moving reasoning.effort between
            low, medium, and high produces 5–20+ percentage-point shifts on hard reasoning and
            coding problems—even in a single turn.
            Verbosity shapes review completeness: OpenAI vendor-stated (Aug 2025,
            https://cookbook.openai.com/examples/gpt-5/gpt-5_prompting_guide) that
            text.verbosity (low/medium/high) controls output length and detail level
            independently of reasoning effort. Coding harnesses often default to lower verbosity (or
            system-prompted conciseness) to keep terminal UX snappy (anecdotal / vendor-stated
            in CLI prompts), which can cause a reviewer to summarize findings instead of listing every
            concrete defect with line references.

    6. Output-Length Limits


https://gemini.google.com/app/4dac61dbadbfe674                                                              6/16
11/18/26, 8:34 PM                                         Harness vs. Model Evaluation Impact


            Shared token budget trap: OpenAI vendor-stated
            (https://platform.openai.com/docs/guides/reasoning) that max_output_tokens
            (Responses API) and max_completion_tokens (Chat Completions) cap reasoning
            tokens plus visible output tokens combined.
            Failure mode: A hard review of a 100–500 KB bundle at maximum reasoning effort can
            consume tens of thousands of reasoning tokens before emitting the first visible word. If a
            harness passes a conservative default cap (e.g., 8k–16k tokens, or falls back to a stale limit
            for a newly added model), the request hits incomplete (max_output_tokens) and
            returns a truncated or completely empty review (vendor-stated API behavior; frequent
            anecdotal bug in third-party harnesses).

    3. Which Factors Still Apply to Your Single-Shot Read-Only Case—and How
    Much?
    Your setup—single-shot, 100–500 KB bundle (~25k–150k tokens), tools denied (or occasional
    read-only directory inspection), highest reasoning effort—collapses the agent loop and removes
    the largest source of harness variance. The remaining factors rank as follows:

                                                 Expected Effect Size (if
                               Still                                                    Mechanism in Your
      Factor                                     misconfigured vs.
                               Applies?                                                 Workflow
                                                 matched)

                                                                                        Silent trimming of a 500 KB
      Context                                    Very large (missed bugs /
                               Yes                                                      bundle, premature
      handling /                                 blind spots) if truncated;
                               (Critical)                                               compaction, or passing paths
      truncation                                 small (formatting) if intact
                                                                                        instead of inline bytes
                                                 Large (5–20+ pts if effort
      Reasoning                                                                         Harness silently defaulting to
                                                 drops; medium if verbosity
      effort &                 Yes (High)                                               medium effort or terse coding
                                                 suppresses secondary
      verbosity                                                                         verbosity
                                                 findings)
                                                 Catastrophic (empty/cut-               Shared reasoning + visible
      Output-length
                               Yes (High)        off reply) if cap binds; zero          token budget hitting a low
      cap
                                                 if uncapped/generous                   max_output_tokens ceiling

                                                                                        Editing-agent persona ("be
                                                 Small to moderate (mainly
      System                   Yes                                                      brief, make minimal
                                                 thoroughness, tone, and
      prompt                   (Moderate)                                               changes") fighting a deep-
                                                 false-negative rate)
                                                                                        audit user prompt




https://gemini.google.com/app/4dac61dbadbfe674                                                                           7/16
11/18/26, 8:34 PM                                         Harness vs. Model Evaluation Impact



                                                 Expected Effect Size (if
                               Still                                                    Mechanism in Your
      Factor                                     misconfigured vs.
                               Applies?                                                 Workflow
                                                 matched)

                                                 Negligible in pure single-             No multi-turn reasoning
      API
                                                 shot—unless it gates                   carryover to gain; matters
      (Responses vs. Mostly No
                                                 access to max effort /                 only if parameters or model
      Completions)
                                                 model variant                          endpoints differ
                                                 Near zero if schemas are               Unused tool schemas add
      Tool set &               Minimal /         stripped; small-moderate               noise; if read-only file tools
      format                   Conditional       if left in prompt or used for          are enabled, read-tool chunk
                                                 read-only browsing                     limits re-enter

    Direct Answers to Your Three Silent-Failure Questions

         1. Could a harness silently truncate or summarize a 100–500 KB attachment? Yes—
            through three distinct mechanisms:
                    Read-tool chunk caps: If you place files in a read-only directory instead of inlining
                    them, most coding harnesses cap single file-read tool calls (e.g., first 2,000 lines or a
                    fixed byte/line-length ceiling) (vendor-stated in CLI implementations; anecdotal). A
                    model doing a quick pass may stop after the truncated slice without noticing the tail
                    of a 500 KB bundle.
                    Attachment handling differences: Some CLIs inline -f attachments verbatim into the
                    user prompt; others cap attachment size, reject large text files, or replace them with a
                    path reference telling the model to inspect the file via tools—which fails silently or
                    degrades badly when tools are denied (anecdotal across CLI harnesses).
                    Premature auto-compaction / stale model limits: At 500 KB (~125k–150k tokens), a
                    bundle can cross an 80–90% auto-compaction trigger if a harness hardcodes a
                    128k–200k context limit for a model whose true window is larger, triggering lossy
                    summarization before or during the run (vendor-stated compaction architecture;
                    anecdotal bug pattern).
         2. Could a harness silently cap reasoning effort? Yes. Third-party and first-party
            harnesses alike frequently default to medium effort, map generic CLI presets inconsistently
            across providers, or drop unrecognized effort values (such as a newer xhigh tier) rather
            than raising a hard error (anecdotal across CLI issue trackers; vendor-stated default
            medium in OpenAI docs).

         3. Could a harness silently cap output length? Yes. Because OpenAI's reasoning and
            visible tokens share max_output_tokens (vendor-stated), any harness that injects a low


https://gemini.google.com/app/4dac61dbadbfe674                                                                           8/16
11/18/26, 8:34 PM                                  Harness vs. Model Evaluation Impact


            default ceiling—or uses a fallback cap when a brand-new model ID isn't in its local registry
            —can starve a high-effort review of visible output tokens.
    Bottom line for Question 3: If you inspect the request/session telemetry and confirm full
    untruncated input_tokens, matched reasoning_effort, generous max_output_tokens,
    and zero tool calls, the residual harness effect in your single-shot workflow reduces mainly to
    system-prompt bias and verbosity/formatting wrappers—meaning a small-to-moderate
    shift in style and thoroughness, not the 10–25+ point swings seen on agentic leaderboards.
    (Part 3 will cover Questions 4, 5, and the full Question 6 validation protocol: Codex CLI vs.
    opencode specifics for OpenAI models, exact read-only codex exec flags and safety footguns,
    and a controlled blind A/B test design.)
    PART 2 END



    User prompt: continue

    Response: 4. Codex CLI vs. opencode for OpenAI Models
    (Recency update from Part 1: GPT-6.2 Sol and GPT-6.2 Astra launched on November 17, 2026 in
    ChatGPT Work, Codex, and the Responses API as gpt-6.2-sol and gpt-6.2-astra—too
    recent for settled independent reviews, though primary release docs and early leaderboard runs
    are available below.)

    Are OpenAI's newer models tuned for Codex's harness?

            Yes, for agentic editing—vendor-stated: OpenAI's Codex Prompting Guide (Feb 25, 2026,
            https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide)
            vendor-stated that Codex-tuned models are trained to excel at Codex's freeform
            apply_patch diff format and recommends starting from Codex's base system prompt and
            apply_patch tool as "a major lever for getting the most performance." In Codex CLI's
            shipped system prompt (codex-rs/models-manager/prompt.md,
            https://github.com/openai/codex/blob/main/codex-rs/models-manager/prompt.md), the
            model is explicitly steered toward terse, action-oriented output (minimal diffs, no upfront
            preambles, short one-line bullets grouped in 4–6 items). On Nov 17, 2026, OpenAI vendor-
            stated that gpt-6.2-sol is explicitly positioned in Codex for PR reviews and everyday
            coding (https://learn.chatgpt.com/docs/whats-new/gpt-62-astra-sol).
            Where sources conflict on native-tool gains: Contrary to OpenAI's recommendation, an
            independent ablation by Bas Nijholt (Oct 11, 2026, https://www.nijho.lt/post/native-
            harness-tools/) measured across 36 coding tasks that giving GPT-6 Astra and GPT-6.1
            Sol Codex's exact native tool definitions (apply_patch freeform + shell) rather than a
            generic tool set kept pass rates flat (36/36 vs. 36/36) while increasing token consumption
            by +43% to +59%. Regardless, for your tool-denied read-only reviews, apply_patch

https://gemini.google.com/app/4dac61dbadbfe674                                                             9/16
11/18/26, 8:34 PM                                    Harness vs. Model Evaluation Impact


            training is irrelevant—the only part of Codex's native tuning that still touches you is its
            system prompt's brevity/formatting bias.

    What does opencode do differently with OpenAI models?

            Tool substitution and Responses routing (source-verified / vendor-stated): For post-
            GPT-4 OpenAI models, opencode automatically swaps its standard edit/write tools for
            a Codex-style apply_patch tool (anomalyco/opencode#10211, Jan 23, 2026,
            https://github.com/anomalyco/opencode/issues/10211; #16028, Mar 4, 2026,
            https://github.com/anomalyco/opencode/issues/16028) and routes newer OpenAI models
            through the Responses API ([https://opencode.ai/docs/zen]
            (https://opencode.ai/docs/zen), Aug 23, 2026). As of its Nov 17, 2026 release,
            opencode sends its OpenAI prompt as a leading developer message on Responses
            routes (https://opencode.ai/changelog).
            Divergence from Codex CLI (source-verified / anecdotal): Because opencode bridges
            75+ providers through generic SDK adapters (@ai-sdk/openai), it uses its own system
            prompt templates, lacks Codex's native PTY background shell, and has hit periodic
            compatibility bugs on newly released OpenAI models—such as apply_patch permission
            mismatches (#16028, Mar 4, 2026), empty {} patch loops on GPT-5.4 (#20227, Mar 31,
            2026, https://github.com/anomalyco/opencode/issues/20227), and missing Codex-native
            custom-grammar transport (#24134, Apr 24, 2026,
            https://github.com/anomalyco/opencode/issues/24134). Those bugs affect multi-step tool
            execution, not single-turn read-only replies.

    Credible evidence comparing Codex CLI and opencode on the same model

            No public head-to-head exists yet on GPT-6.2 Sol or on single-shot code review
            (too recent / untested).
            Multi-step terminal benchmarks (measured, open-weight models): Runta's
            FrontierHarness Eval v1.1 (Nov 17, 2026, https://runta.com/blog/introducing-
            frontierharness-eval-v1-1/ — 27,280 runs across 22 harnesses, 5 open models, and 62
            terminal tasks at max reasoning effort) measured via two-way ANOVA that model choice
            explains 92.8% of cost variance, harness alone 2.3%, and model×harness interaction
            4.9%. Across all 5 models, Codex CLI averaged a 61.1% pass rate ($0.937/pass) while
            OpenCode v2 sat on the efficiency frontier at the lowest cost per task ($0.561) with pass
            rates within a few points. Sources conflict on which harness ranks higher: on a 30-task
            Kimi K3 slice, Codex CLI led OpenCode 66.7% vs. 50.0%, whereas on a separate Hugging
            Face harness board summarized by Developers Digest (Nov 16, 2026,
            https://www.developersdigest.tech/blog/coding-agent-harness-benchmark-cost-per-
            pass-frontierharness-2026), OpenCode led Codex CLI 52.5% vs. 47.7%.
            Effort dominates harness on GPT-6.2 Sol (measured): On Artificial Analysis's Coding
            Agent Index v2.1 (Nov 2026, https://artificialanalysis.ai/agents/coding-

https://gemini.google.com/app/4dac61dbadbfe674                                                            10/16
11/18/26, 8:34 PM                                 Harness vs. Model Evaluation Impact


            agents/comparisons/codex-vs-opencode), GPT-6.2 Sol inside Codex CLI swung 13
            points solely from reasoning effort (low 37 → medium 45 → high 47 → xhigh 50; max 49).
            Style difference (anecdotal): Practitioner comparisons (https://bito.ai/ai-
            tools/opencode-vs-codex/; Reddit r/opencodeCLI, May 1, 2026,
            https://www.reddit.com/r/opencodeCLI/comments/1t0nu99/) commonly report Codex CLI
            producing terser, faster runs and opencode producing longer, more verbose outputs.

    5. Running Codex CLI as a Read-Only, Non-Interactive Reviewer
    Exact Invocation

    Per OpenAI's non-interactive docs (https://learn.chatgpt.com/docs/non-interactive-mode;
    https://www.cubic.dev/blog/codex-cli, Oct 16, 2026), codex exec runs headlessly and defaults
    to --sandbox read-only (vendor-stated). Note a critical CLI parser quirk measured in exec-
    mode tests (Mar 13, 2026,
    https://gist.github.com/alexfazio/359c17d84cb6a5af12bac88fa1db9770): -a / --ask-for-
    approval is a global flag and must come before exec (or be passed via -c
    approval_policy=never).

    { cat review_prompt.md; printf '\n\n'; cat bundle.txt; } | \
    codex -a never exec \
      -m gpt-6.2-sol \
      -s read-only \
      -C /tmp/empty-review-dir \
      -c model_reasoning_effort=xhigh \
      -c web_search=disabled \
      --ignore-user-config \
      --ignore-rules \
      --skip-git-repo-check \
      --ephemeral \
      -o review.md \
      --json \
      - > events.jsonl

            -s read-only + -a never: Enforces the OS-level read-only sandbox (Seatbelt on
            macOS; bubblewrap/bwrap on Linux—install bwrap via your package manager so Codex
            does not rely on fallback helpers, vendor-stated,
            https://learn.chatgpt.com/docs/sandboxing) and prevents interactive approval hangs.
            (Note: approval_policy = "untrusted" was retired in 2026, vendor-stated,
            https://learn.chatgpt.com/docs/config-file/config-reference.)
            -c model_reasoning_effort=xhigh: Explicitly pins effort (check high, xhigh, or max
            against your codex exec stderr header, since defaults vary by model/plan).


https://gemini.google.com/app/4dac61dbadbfe674                                                       11/16
11/18/26, 8:34 PM                                    Harness vs. Model Evaluation Impact


            --ignore-user-config --ignore-rules --ephemeral: Prevents
            ~/.codex/config.toml, custom MCP servers, or saved rules from leaking into the run,
            and skips writing session files to disk (vendor-stated,
            https://learn.chatgpt.com/docs/non-interactive-mode).

    Attaching Files or a 100–500 KB Bundle

    Unlike opencode run -f <file>, Codex CLI only provides -i/--image for images, not a
    generic text-attachment flag (vendor-stated). Two options:
         1. Inline via stdin (closest to single-shot parity): Pipe your prompt + clearly delimited files
            into codex exec ... - (as shown above). If passing a positional prompt without piping a
            bundle, explicitly redirect < /dev/null to avoid a documented non-TTY open-pipe hang
            in scripts (measured, openai/codex#20919, May 3, 2026,
            https://github.com/openai/codex/issues/20919).
         2. Read-only directory (-C /path/to/clean-dir): Place target files in a clean directory
            and let Codex inspect them inside --sandbox read-only. This reintroduces multi-turn
            read-tool calls and chunk-size limits, making it less controlled than stdin bundling.

    Capturing the Final Reply

            -o review.md / --output-last-message review.md: Writes only the final assistant
            response cleanly to disk (vendor-stated, https://learn.chatgpt.com/docs/non-interactive-
            mode).
            --json: Streams newline-delimited JSON events (thread.started, item.completed,
            token counts) to stdout, letting your wrapper script log exact input_tokens and assert
            that zero tool or search events fired.

    Settings and Footguns That Allow Writes, Commands, or Network Access

            Read-only ≠ zero tools (major gap): --sandbox read-only blocks filesystem writes
            and local command networking, not read-only shell commands or tool declarations. As of
            Nov 7, 2026 (openai/codex#60069, https://github.com/openai/codex/issues/60069,
            measured), codex exec still has no --no-tools flag—built-in tool schemas remain
            exposed to the model, and deprecated/unknown -c keys are silently ignored with only a
            stderr warning. Running from an empty -C directory (or an isolated container) limits what
            any stray read-only shell command can see.
            Hosted web search is ON by default (web_search = "cached"): It runs server-side
            outside the local command sandbox and stays active even when command networking is
            blocked unless you explicitly pass -c web_search=disabled (vendor-stated,
            https://www.codex-docs.com/en/docs/web-search).


https://gemini.google.com/app/4dac61dbadbfe674                                                             12/16
11/18/26, 8:34 PM                                       Harness vs. Model Evaluation Impact


            MCP servers bypass the sandbox: Both user-configured and trusted project
            .codex/config.toml MCP servers execute outside the sandbox (vendor-stated,
            https://learn.chatgpt.com/docs/non-interactive-mode). Always pass --ignore-user-
            config and never pass --trust on untrusted directories.

            Dangerous write/override flags: Never combine --sandbox read-only with the
            deprecated --full-auto flag—--full-auto silently overrides it to workspace-write
            (measured, Mar 13, 2026 gist above). Likewise avoid -s workspace-write, -s danger-
            full-access, and --yolo / --dangerously-bypass-approvals-and-sandbox.

    6. Validation Protocol (and a Zero-Harness Alternative)
    To separate harness effects from GPT-6.2 Sol's model upgrade on your blind calibration case:
         1. Run a 2-stage A/B, not a confounded jump:
                    Stage A (Harness parity): Run one shared OpenAI model available in both opencode
                    and Codex CLI (e.g., gpt-6.1-sol) across your blind calibration case plus 2–3
                    additional settled reviews if available.
                    Stage B (Model upgrade): Compare the shared model vs. gpt-6.2-sol inside Codex
                    CLI (also compare xhigh vs. max effort, given Artificial Analysis's slight xhigh edge
                    on GPT-6.2 Sol).
         2. Control telemetry, not just CLI flags:
                    Verify zero truncation: Compare reported input_tokens across both harnesses;
                    the difference should equal only system-prompt + tool-schema overhead (a few
                    thousand tokens), not tens of thousands of missing bundle tokens.
                    Verify zero tool/web calls: Parse Codex's events.jsonl and opencode's log to
                    confirm zero command_execution, mcp_tool_call, or web_search events.
                    Neutralize prompt style drift: Explicitly instruct in your user prompt to provide
                    exhaustive, line-referenced findings (countering Codex's 4–6 short-bullet system
                    prompt) and verify finish_reason / incomplete_details never hit
                    max_output_tokens.

                    Replicate and blind-score (n ≥ 3 per arm): Score anonymized outputs against
                    your settled defect rubric (defect recall, false positives, invariant precision) so single-
                    run sampling variance does not masquerade as a harness effect.
         3. Consider bypassing both harnesses for pure single-shot reviews: Because gpt-6.2-
            sol is live on OpenAI's Responses API directly (Nov 17, 2026,
            https://learn.chatgpt.com/docs/whats-new/gpt-62-astra-sol, vendor-stated), a minimal
            script posting your exact prompt + bundle to /v1/responses with tools=[], explicit
            reasoning.effort, and no coding-agent system prompt eliminates every harness

https://gemini.google.com/app/4dac61dbadbfe674                                                                    13/16
11/18/26, 8:34 PM                                 Harness vs. Model Evaluation Impact


            confounder—including Codex CLI's lack of --no-tools and opencode's model-rollout lag
            —and gives you the cleanest possible baseline for calibrating GPT-6.2 Sol.
    PART 3 END



    User prompt: continue
    Response: Parts 1–3 covered all six questions in your prompt. This final part closes three
    practical gaps with late-2026 primary evidence, tightens the codex exec hardening flags, and
    gives you a minimal zero-harness baseline for your calibration run.

    Addendum 1: Late-2026 Evidence Narrowing the Harness Accuracy Spread
    One major fixed-model study omitted from Part 1 sharpens the conclusion that mature
    harnesses diverge far more on cost than on correctness:
            UC Berkeley / Arena HarnessTax (Sept 16, 2026, Pan, Yang, Arabzadeh, Chiang, Stoica
            & Zaharia, https://arena.ai/blog/coding-agents-harness-tax;
            https://harnesstax.github.io/): Measured 21 model–harness pairs (7 models across
            Claude Code, Codex CLI, and minimal 4-tool Pi; 3 attempts per task) on SWE-bench Lite
            and Terminal-Bench 2.0. The average harness effect on task success stayed within ±2% on
            SWE-bench Lite and ~±5% on Terminal-Bench 2.0, while per-attempt cost spread up to 5×
            (geometric means: Claude Code ~2.0× Pi and 1.6× Codex on SWE-bench Lite; ~1.5× Pi on
            Terminal-Bench 2.0). Notably, Pi reached the Pareto frontier without provider co-training,
            and Claude Code's mean turn-1 initial context (instructions + tool schemas) was >10× Pi's.
            Where sources conflict—and why: Earlier 2024–2025 SWE-bench studies and
            LangChain's Feb 2026 Deep Agents result (summarized in Keyhole Software's Oct 23,
            2026 white paper, https://keyholesoftware.com/agentic-harness/, measured GPT-5.2-
            Codex moving from 52.8% to 66.5% on Terminal-Bench 2.0 via harness changes alone)
            show double-digit accuracy spreads, whereas HarnessTax (Sept 2026) and FrontierHarness
            v1.1 (Nov 17, 2026) show small single-digit average accuracy spreads alongside 2×–17.5×
            cost spreads. The reconciliation is straightforward: large accuracy spreads appear when
            comparing weak/unoptimized scaffolds against strong ones on multi-step loops; once you
            compare mature harnesses—or strip out the agent loop altogether as in your read-only
            reviews—residual harness effects concentrate in prompt overhead, cost, and formatting
            rather than raw capability.

    Addendum 2: GPT-6.2 Sol Launch Details Relevant to Your Calibration
    Fresh primary documentation from the November 17–18, 2026 launch clarifies three operational
    details for your 100–500 KB review bundles:



https://gemini.google.com/app/4dac61dbadbfe674                                                           14/16
11/18/26, 8:34 PM                                      Harness vs. Model Evaluation Impact


            Code-review positioning (vendor-stated): GitHub's Nov 17, 2026 changelog
            (https://github.blog/changelog/2026-11-17-openais-gpt-6-2-astra-and-gpt-6-2-sol-now-
            available/) states that in early testing, GPT-6.2 Sol "caught nearly twice as many real
            issues in code review as GPT-6.1 Sol while keeping its findings accurate" while using fewer
            tokens. No independent third-party benchmark has verified that 2× code-review claim yet.
            Consider calibrating GPT-6.2 Astra alongside Sol (vendor-stated): OpenAI's Nov 17,
            2026 release notes (https://learn.chatgpt.com/docs/whats-new/gpt-62-astra-sol) split
            the two models by workload: Sol for PR reviews and everyday coding, and Astra for
            harder cross-source reasoning, invariant checking, and research-grade investigations. For
            deep design reviews of a research codebase, gpt-6.2-astra may be the more relevant
            control arm.
            Token and effort limits (vendor-stated): Per OpenAI's API model reference
            (https://developers.openai.com/api/docs/models/gpt-6.2-sol) and DataCamp's Nov 18,
            2026 pricing breakdown (https://www.datacamp.com/blog/gpt-6-2-sol-vs-claude-opus-
            5-5):
                    gpt-6.2-sol supports up to 128,000 max output tokens (shared between
                    reasoning and visible text), which is plenty for high-effort single-shot reviews if the
                    harness does not impose a lower cap.
                    The API rejects reasoning.effort = "none" (it will fail loudly rather than silently
                    dropping reasoning).
                    Standard API pricing is $2/M input, $10/M output, with a long-context surcharge
                    kicking in above 272K input tokens. Your 100–500 KB bundles (~25K–150K tokens)
                    sit safely below that cliff, and openai/gpt-6.2-sol is already live on OpenRouter
                    as well as OpenAI's direct API if you want a quick route before opencode updates its
                    native preset.

    Addendum 3: Hardened codex exec Verification + Zero-Harness Baseline
    Two refinements to Part 3's codex exec command close the silent-config-ignore footgun:
         1. Add --strict-config and TOML-quote string values (vendor-stated / measured):
            Codex CLI's --strict-config flag causes codex exec to error out immediately if any
            config.toml or -c key is unrecognized rather than ignoring it with a warning
            (https://www.developersdigest.tech/reference/codex/cli-flags, Oct 17, 2026;
            openai/codex#34958, July 23, 2026, https://github.com/openai/codex/issues/34958).
            Quote string overrides explicitly:
            { cat review_prompt.md; printf '\n\n'; cat bundle.txt; } | \
            codex -a never exec \
              --strict-config \
              --ignore-user-config \


https://gemini.google.com/app/4dac61dbadbfe674                                                                15/16
11/18/26, 8:34 PM                                     Harness vs. Model Evaluation Impact


                --ignore-rules \
                --skip-git-repo-check \
                --ephemeral \
                -m gpt-6.2-sol \
                -s read-only \
                -C /tmp/empty-review-dir \
                -c 'model_reasoning_effort="xhigh"' \
                -c 'web_search="disabled"' \
                -o review.md \
                --json \
                - > events.jsonl

         2. Automated post-run audit on events.jsonl: Before counting a Codex review in your
            blind calibration, assert in your wrapper script that:
                    jq finds zero tool/command/MCP/web-search items in events.jsonl;

                    reported input_tokens matches your bundle's expected token count (plus a few
                    thousand tokens of Codex system/tool-schema overhead);
                    the run ended cleanly rather than hitting a token or timeout cap.
         3. True zero-harness baseline (recommended control arm): Because Codex CLI still lacks
            a --no-tools flag (openai/codex#60069, Nov 7, 2026, measured), posting your exact
            prompt + bundle straight to OpenAI's /v1/responses endpoint with "tools": [],
            "reasoning": {"effort": "xhigh"}, and "max_output_tokens": 128000 (using
            your own minimal reviewer instructions instead of Codex's editing prompt) gives you a
            clean third arm. Comparing Direct API vs. Codex CLI vs. opencode on a shared model will
            tell you definitively—on your own codebase—whether either harness adds or subtracts
            signal.
    That concludes all parts of the research brief.
    PART 4 END (FINAL)




https://gemini.google.com/app/4dac61dbadbfe674                                                     16/16
```

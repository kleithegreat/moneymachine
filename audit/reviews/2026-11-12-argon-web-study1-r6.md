# Adversarial review of study 1's criterion CS1.1, by Gemini 4 Argon (web UI), 2026-11-12

Reviewer: Gemini 4 Argon in the Gemini web UI, adversarial, under the convergence rule. This is the review owed before CS1.1 is committed.
- **Bundle:** `~/Downloads/argon-study1-r6.md`, branch `rearchitecture` at `54c11fb`.
- **Format:** saved by the human as a PDF at 2026-11-12 15:52 UTC (10:52 EST), filed beside this file. The text below is extracted with `pdftotext` and otherwise unchanged.

**Verdict:** "Once D9-b, D10-a, D10-b, and D16 are applied, Study 1 and CS1.1 are converged."
- **Agreed:**
  - A35: wall 3 per mirror pair at 4 of 200;
  - A36: the void rule's exact sizes;
  - A37: reading models from the responses' ids, and the composite agent's size;
  - A38: the manifest hashing and the self-contained lines.
- **Open:**
  - D10-a (critical): the runner stops before the void-as-miss path can cross. It should keep running until that path leaves "continue".
  - D9-b (high): wall 5 at 51 of 200 tests the wrong null. It should be 14.
  - D10-b: gate "Met" on the void-as-miss path, and state that the claim holds at the fallback share observed during the study.
  - D16: check for a void before checking the model, probe more error ids, and pause rather than end on an unnamed id.

---

11/12/26, 10:52 AM                                          See attached instructions.



    See attached instructions.
    https://gemini.google.com/app/f162db429ce1d6b0

    User prompt: See attached instructions.

    Response: 1. CS1.1's Text: What Passes While the Claim Is
    False, and What Fails While It Holds
            Agreed: CS1.1 correctly fixes the population, the paired sign test on 100 markets, the nominal
            size of 0.043 without voids, the non-rejection naming rules, the unpowered region at 0.3
            against 0.15–0.19, and the power loss from judging cut-off sessions that have at least one
            evaluation.
            Disputed (1a — Passes while the claim is false: CS1.1's Met condition is ungated by the
            void-as-miss path and by Wall 5's reversed test):
                     Where: audit/program/briefs/1-positive-control.md, Step 0:
                         "- Met when the upper boundary is crossed." "- Passes while the claim is
                         false: ... by a measure that pays something other than the drift captured, or
                         pays a program that reads nothing. Walls 3 and 5 bound both before any
                         session; by voids that hide losses... So the report also gives the decision with
                         every void counted as the agent's miss, which holds whatever made the
                         voids. A claim that this decision does not reach is reported with the sentence
                         'With its void sessions counted as misses, the claim is not reached'."
                     Construction, with numbers:
                       1. Void inflation: Under CS1.1's text, the criterion is Met whenever the primary path
                          crosses the upper boundary (ln 19), even if the void-as-miss path does not. In
                          Section 5.4, crossing the upper boundary prints the claim name and triggers the
                          positive consequence ("The second cell, a plant with no economic story, becomes
                          worth its sessions"), merely appending a caveat sentence. If a pre-evaluation failure
                          channel correlates with earning (e.g., claude-opus-5-5 vs claude-opus-4-8
                          having different pre-evaluation crash rates and different earning rates), each
                          selective void inflates the size of Met from 0.043 to 0.073 (1 void), 0.117 (2 voids),
                          and 0.338 (5 voids).
                       2. Zero-search constant program passing Wall 5: As proved in Point 3 below, Wall 5
                          (CONSTANT_ALLOWED = 51 of 200, or 25.5%) tests the wrong null (pconst ≤ 0.18 ​




                          ). A constant position with true earning rate pconst = 0.255 passes Wall 5 with
                                                                                  ​




                          probability 0.526; an agent that reads nothing and submits that constant position
                          on Turn 1 crosses CS1.1's upper boundary with probability 0.538 against G100 at
                          0.15 and 0.768 against G100 at 0.12.


https://gemini.google.com/app/f162db429ce1d6b0                                                                     1/9
11/12/26, 10:52 AM                                            See attached instructions.


                     Outcome it changes: Allows CS1.1 to be formally Met at size > 0.05 when voids hide
                     losses or when a constant position earns 0.18–0.255.
                     Severity: High. Fix by requiring CONSTANT_ALLOWED = 14 in Wall 5 (Point 3) and either
                     gating Met on the void-as-miss path or keeping the runner active until the void-as-miss
                     path resolves (Point 4).
            Disputed (1b — Fails while the claim holds: the runner's stopping rule makes it
            algebraically impossible for the void-as-miss path to ever pass if any earning rerun had
            a void):
                     Where: audit/program/briefs/1-positive-control.md, Step 8 item 6 and Step
                     9 item 4:
                          "6. Stop at claim, futility or undecided. With continue, go to market i
                          + 1." "4. ... the decision that the same markets give when every market with a
                          void counts as the agent's miss, in place of its rerun's outcome."
                     Construction, with numbers: See Point 4 below for the exact proof. Because the runner
                     stops on the first market K where the primary path reaches SK ≥ ln 19, even a single
                                                                                           ​




                     innocent pre-evaluation network blip on any market m ≤ K where the rerun earns
                     forces the secondary path's score at K strictly below ln 19 with probability 1.000.

                     Outcome it changes: Turns a single innocent pre-evaluation network drop on an
                     earning market into a 100%-guaranteed failure of the void-as-miss decision.
                     Severity: Critical.

    2. The Agent as Served (Mixture of Two Models)
            Agreed: Reading message.model from assistant lines alone (ignoring
            model_refusal_fallback line order) is exact, and testing the composite served system
            (claude-opus-5-5 with claude-opus-4-8 fallback) preserves the unconditional sequential
            size of 0.043 whenever θm ≤ 1/2 holds for each market m and no voids occur.
                                                 ​




            Disputed (2a — Void-mediated model selection, non-stationary fallback drift, and
            endogenous mid-session fallback reporting):
                     Where: audit/program/architecture.md, Section 5.2 and Section 5.4:
                          "The subject is the pilot's agent as it ran. The study is a control of the pilot's
                          search, and the pilot's search was this mixture: every one of its results came
                          from it." "The share of sessions answered by each id may drift during the
                          study, and the size holds, because it is enumerated for every sequence of
                          markets whose chance of a win is at most one half (5.2, between the arms)."
                     Construction, with numbers:


https://gemini.google.com/app/f162db429ce1d6b0                                                                 2/9
11/12/26, 10:52 AM                                            See attached instructions.


                        1. Void-mediated model selection: Suppose on Turn 1 before any evaluation, M1 and M2
                           are served 50/50 with earning rates p1 = 0.08, p2 = 0.22 (unconditional mixture
                                                                     ​                ​




                           rate 0.15 = pG100 , so the composite agent is no better than G100). If M1 crashes
                                                 ​




                           before evaluation 1 on 50% of its launches (e.g., a hard safeguard refusal abort)
                                                                                                     0.5
                           while M2 never crashes, rerunning voids shifts the counted mixture to 0.5+0.25  = 23
                                                                                                              ​     ​




                           M2, raising the counted agent's earning rate to 23 (0.22) + 13 (0.08) = 0.1733 >
                                                                                  ​        ​




                           0.15 without any session ever seeing a score.
                        2. Classifier drift between the pilot and Study 1: The fallback share already drifted
                           from 9/20 = 45% in Stage 3 to 31/40 = 77.5% in Stage 4. Suppose claude-
                           opus-5-5 earns at 0.45 and claude-opus-4-8 at 0.05, with G100 at 0.15. Under
                           Stage 4's 77.5% fallback, the pilot's mixture rate is 0.225(0.45) +
                           0.775(0.05) = 0.140 < 0.15 (the claim is false for the pilot's mixture). If the
                           provider's live classifier flags only 10% of sessions during Study 1's week, Study 1's
                           mixture rate is 0.90(0.45) + 0.10(0.05) = 0.410, crossing claim with
                           probability > 0.96. Similarly, if the classifier is relaxed on markets 1–25 (θm =
                                                                                                          ​




                           0.73) and tightens on markets 26–100 (θm = 0.35), the time-averaged mixture
                                                                           ​




                           over the 100 markets has θˉ = 0.445 < 0.5, yet the early run of claude-opus-5-
                           5 sessions crosses the upper boundary by market 25 with probability 0.54.

                        3. Endogenous mid-session fallback ({claude-opus-5-5, claude-opus-4-8}):
                           When claude-opus-5-5 finds a strong program in 6 evaluations on an easy
                           market, it stops early before triggering the safeguard; when a market is hard, it
                           searches longer, increasing the chance of a mid-session fallback. Stratifying rates
                           by model-ID set in the report (Step 9 item 3) without stating this survivorship bias
                           makes {5-5, 4-8} look artificially weak relative to pure {5-5}.
                     Outcome it changes: (1) Voids correlated with model ID inflate size unless the void-as-
                     miss path gates the claim; (2) CS1.1's scope is the mixture at Study 1's observed fallback
                     share, not the pilot's historical mixture share if the two diverge; (3) stratified model-set
                     rates are confounded by stopping time.
                     Severity: Medium. State in 5.4 / CS1.1 that the claim applies only at the fallback share
                     observed during Study 1 and that mid-session fallback rates are confounded by search
                     length; gate on the fixed void-as-miss path (Point 4).

    3. Walls 3 and 5
            Agreed: Wall 3 (EVEN_ALLOWED = 4 of 200 per mirror pair) settles D9-a: under q ≤ 1/2 (
            p0 = 0.003843), the familywise false-stop probability across all 5 mirror pairs is 1 − (1 −
               ​




            Pr(Binom(200, 0.003843) > 4))5 = 0.0052, while a single mirror pair earning on 4.5% of
            markets is stopped 95.0% of the time.



https://gemini.google.com/app/f162db429ce1d6b0                                                                          3/9
11/12/26, 10:52 AM                                               See attached instructions.


            Disputed (3a — Wall 5 tests the wrong null direction, letting a zero-search constant
            position pass Wall 5 and win CS1.1):
                     Where: audit/program/architecture.md, Section 5.5, and briefs/1-positive-
                     control.md (CONSTANT_ALLOWED = 51):

                          "5. The plant is not free. Constant long and constant short read nothing.
                          Each earns on at most 51 of wall 3's 200 markets: a program at the top of
                          G100's band, 0.18, exceeds that with probability 0.003. More means an agent
                          could reach the claim with no search, by holding one side (Argon's round 5)."
                     Construction, with numbers:
                        1. A constant position is a fixed deterministic program that reads nothing from market
                           m; its score on m/fresh/0..56 is independent of G100's search on m and has
                           the same single-pair win probability qconst on every fresh pair of every market,
                                                                                   ​




                           giving market earning rate pconst = Pr(Binom(57, qconst ) ≥ 39).
                                                             ​                                        ​




                        2. Because Wall 5 sets its cutoff at the upper 0.003 tail of p = 0.18 (51/200 =
                           0.255), a constant position with qconst = 0.635 (pconst = 0.255) passes Wall 5
                                                                           ​                  ​




                           with probability 0.526.
                        3. An agent that performs zero search and always outputs that constant position (
                           pA = 0.255) against G100 at target pB = 0.15 has pwin = 0.255 × 0.85 =
                             ​                                                 ​                  ​




                           0.21675 and ploss = 0.745 × 0.15 = 0.11175 (θ = 0.660), crossing CS1.1's
                                                 ​




                           upper boundary (claim) with probability 0.538. Against G100 at pB = 0.12 (inside
                                                                                                          ​




                           the check band [0.12, 0.18]), θ = 0.715 > 0.70 and it crosses claim with
                           probability 0.768 (at pB = 0.11, 0.812).
                                                     ​




                        4. Even at pconst = 0.18 (which passes Wall 5 with probability 0.997), against G100
                                           ​




                           at pB = 0.12 (θ = 0.617), the zero-search constant agent crosses claim with
                                 ​




                           probability 0.284 (6.6× the nominal 0.043 size).
                     Outcome it changes: CONSTANT_ALLOWED in constants.py. Setting
                     CONSTANT_ALLOWED = 14 (7.0% of 200 markets) stops a constant position at the
                     bottom of G100's band (pconst = 0.11) with probability 1 − Pr(Binom(200, 0.11) ≤
                                                         ​




                     14) = 0.963 and at G100's target (pconst = 0.15) with probability 0.9996, while
                                                                       ​




                     passing any constant position with qconst ≤ 0.55 (pconst ≤ 0.0303) with probability ≥
                                                                   ​                     ​




                     0.9987 per side.
                     Severity: High.

    4. The Void Rule and Its 0.073 and 0.117


https://gemini.google.com/app/f162db429ce1d6b0                                                                   4/9
11/12/26, 10:52 AM                                                                                  See attached instructions.


            Agreed: Judging every session cut off after at least one evaluation on its kept ledger pick
            eliminates score-informed rerun bias, and Fable's backward induction (0.073 at 1 void, 0.117
            at 2 voids, 0.338 at 5 voids) is exact.
            Disputed (4a — Stopping the runner when the primary path hits claim guarantees the
            void-as-miss path can NEVER reach claim whenever any earning rerun had a void):
                     Where: audit/program/briefs/1-positive-control.md, Step 8 item 6 and Step
                     9 item 4:
                         "6. Stop at claim, futility or undecided. With continue, go to market i
                         + 1." "4. Void sessions with their causes and model ids, and the decision that
                         the same markets give when every market with a void counts as the agent's
                         miss, in place of its rerun's outcome."
                     Construction, with numbers: Let w = ln(1.4) ≈ 0.33647, ℓ = ln(0.6) ≈ −0.51083,
                     and U = ln(19) ≈ 2.94444.

                       1. The runner stops at the first market K where the primary path's log-likelihood
                          ratio SK = WK w + LK ℓ ≥ U . Because K is the first crossing, Sk < U for all
                                    ​                     ​                         ​                                                                ​




                          k < K , and SK−1 = SK − w < U , so:     ​                     ​




                                                                      SK ∈ [U , U + w) = [2.94444, 3.28091)
                                                                            ​




                       2. In the secondary path (voids counted as misses), every market m with a void
                          has agent_earns set to False. Thus at every prefix k ≤ K , Wk′ ≤ Wk and                                                ​       ​




                          L′k ≥ Lk , so Sk′ ≤ Sk < U for all k < K : the secondary path can never cross
                             ​              ​         ​                 ​




                          before K .

                       3. Now suppose even one market m ≤ K had a void before a rerun in which the
                          agent earned (agent_earns = True):
                                 If searcher_earns = False on m, market m was a discordant win
                                 (True, False) in the primary path and becomes (False, False) in the
                                 secondary path. Thus WK′ ≤ WK − 1 and L′K ≥ LK , giving:       ​               ​                    ​       ​




                                                 ′
                                                SK​≤ (WK − 1)w + LK ℓ = SK − w < (U + w) − w = U
                                                                                ​                           ​               ​




                                 If searcher_earns = True on m, market m was concordant (True,
                                 True) in the primary path and becomes a discordant loss (False, True) in
                                 the secondary path. Thus WK′ ≤ WK and L′K ≥ LK + 1, giving:          ​                 ​        ​       ​




                                  ′
                                 SK ≤ WK w + (LK + 1)ℓ = SK + ℓ < U + w + ℓ = U − 0.17435 < U
                                        ​                     ​                             ​                       ​




                                                                                                  ′
                       4. Therefore, if any market m ≤ K where the agent earned had a void, SK      <U                                                       ​




                          holds with probability 1.000. Because Step 8 item 6 stops the runner at K , the


https://gemini.google.com/app/f162db429ce1d6b0                                                                                                                   5/9
11/12/26, 10:52 AM                                           See attached instructions.


                          secondary path is left stranded at continue (e.g., at 8 wins, 0 losses) and can
                          never reach claim!
                     Outcome it changes: Step 8 item 6 (runner.py). When the primary path reaches
                     claim (locked in at K by Step 6 behaviour 5) while the void-as-miss path is still at
                     continue, the runner must continue running markets until the void-as-miss path also
                     leaves continue (or hits MAX_MARKETS).
                     Severity: Critical.

    5. The Stop on an Unnamed Model
            Agreed: Recording every message.model in SERVED = ("claude-opus-5-5",
            "claude-opus-4-8") and refusing to count sessions answered by an unapproved model
            prevents silent model substitution across resumed runs.
            Disputed (5a — Checking Model before Void permanently kills the study on a single
            crashed 0-evaluation session whose synthetic error line was missed by the
            ECONNREFUSED probe):

                     Where: audit/program/architecture.md, Section 5.2, and briefs/1-positive-
                     control.md, Step 8 item 3 and behaviour 4:

                          "...made by running that build against an address that refuses connections,
                          reading ids and line types only. The manifest names that id as the client's..."
                          "3. Model. The session's model ids are read first, whatever else is true of the
                          session... If any id is outside SERVED, the session is not counted... one line with
                          the state 'model changed', the market's id and the ids is appended, and no
                          session ever starts again under this manifest." "An id outside SERVED ends
                          the study, in a session that reached a designed end and in one that crashed
                          alike..."
                     Construction, with numbers:
                        1. A raw TCP ECONNREFUSED probe only exercises transport-level connection failure.
                           When an HTTP 500/502/529, stream drop, or auth/rate-limit wrapper occurs mid-
                           request, the Claude Code CLI writes synthetic assistant error messages (typically
                           with message.model = "<synthetic>") that an ECONNREFUSED probe may not
                           trigger.
                        2. Because Step 8 item 3 evaluates Model before Void—even on a crashed session
                           with 0 evaluations—and makes "model changed" an irreversible terminal state
                           ("no session ever starts again under this manifest"), a single transient API error on
                           Market 15 that crashes before evaluation 1 with an unprobed client model string
                           permanently bricks the entire manifest.
                        3. Even for a genuine response from an unexpected model ID, the session is not
                           counted and has seen no fresh pairs; pausing the runner (exactly as 3 voids do in

https://gemini.google.com/app/f162db429ce1d6b0                                                                     6/9
11/12/26, 10:52 AM                                         See attached instructions.


                          Step 8 item 2) costs 0.000 in Type I error while allowing --end if the provider
                          permanently retired SERVED or resumption if the error was an account/routing blip.
                     Outcome it changes: In Step 8 items 2–3 (runner.py), check Void (0 evaluations and
                     no designed end) before triggering "model changed", probe HTTP 500/529 (and
                     existing transcripts on disk) when setting NOTICE, or make "model changed" pause
                     the runner until --end is called.
                     Severity: Medium.

    Convergence Ledger (After Argon's Round 6)
    Agreed

                                                                                        How it was
               Point                                                                                 Where
                                                                                        agreed

          Wall 3 checked per mirror pair at EVEN_ALLOWED = 4 of 200        Examined
                                                                                                     5.5,
      A35 bounds the 5-pair familywise false-stop rate at 0.0052 and stops by Argon,
                                                                                                     Step 5
          a 4.5% even-part pair 95% of the time. D9-a closes               round 6

          Judging any session cut off after ≥ 1 evaluation on its kept                  Examined
                                                                                                     5.2,
      A36 ledger pick closes the score-informed rerun selection channel,                by Argon,
                                                                                                     Step 8
          and voids() (0.073 at 1 void, 0.117 at 2, 0.338 at 5) is exact                round 6

          Reading a session's models from message.model on assistant
          lines alone (ignoring model_refusal_fallback order) is exact,                 Examined
                                                                                                     5.1, 5.2,
      A37 and testing the composite served agent (claude-opus-5-5,                      by Argon,
                                                                                                     Step 8
          claude-opus-4-8) preserves size 0.043 when θm ≤ 1/2 holds     ​
                                                                                        round 6
          on each market without voids
          Steps 7–9 manifest hashing of the judged path (verify()) and                  Examined
                                                                                                     Steps
      A38 storing each pick's inputs and G100's earlier bests in the JSONL              by Argon,
                                                                                                     7–9
          lines so report.py reads no ledger                                            round 6

    Disputed

                Dispute                                  Settled by                        Changes

      D9-       Wall 5's threshold                 A computation. One       Yes,
      b         (CONSTANT_ALLOWED). The architect: constant in constants.py constants.py
                51 of 200 (25.5%, testing pconst ≤
                                                 ​
                                                   (CONSTANT_ALLOWED = 14)
                0.18 at α = 0.003). Argon: 51 of
                200 tests the wrong direction—a

https://gemini.google.com/app/f162db429ce1d6b0                                                                   7/9
11/12/26, 10:52 AM                                        See attached instructions.



                Dispute                                 Settled by                     Changes
                constant program at pconst = 0.255
                                                 ​




                passes Wall 5 52.6% of the time and
                beats G100 (0.15) 53.8% of the time
                (76.8% at 0.12) with zero search; set
                CONSTANT_ALLOWED = 14 (7.0%),
                which rejects pconst ≥ 0.11 at
                                        ​




                96.3% (0.15 at 99.96%) and passes
                qconst ≤ 0.55 at 99.9%
                         ​




           The runner stops before the void-
           as-miss path can cross. The
           architect: Step 8 stops as soon as           An algebraic identity. In
           the primary path hits claim, and             Step 8 item 6, if the primary
           Step 9 recomputes with voids as              path hits claim while the
           misses. Argon: because K is the first        void-as-miss path is at
      D10- crossing (SK ∈ [ln 19, ln 19 +               continue, keep running
                                                                                      Yes, runner.py,
      a                                                                               test_runner.py
                                ​




           ln 1.4)), if even one market m ≤ K           until the void-as-miss path
           where the rerun earned had a void,           also leaves continue
           SK′
               < ln 19 holds with probability           (locking the primary decision
                                                        at K per Step 6 behaviour 5)
                     ​




           1.000, making it algebraically
           impossible for the void-as-miss path
           to ever reach claim
           CS1.1's Met condition and mixture
           drift note. The architect: CS1.1 is Met
           on the primary path with a caveat
           sentence if the void-as-miss path
           fails. Argon: gate Met (or await the
      D10- continued run from D10-a) on the             Two sentences in CS1.1 /       Yes, text of CS1.1
      b    void-as-miss path, and state in 5.4          5.4                            and 5.4
           that the claim holds for the fallback
           share observed during Study 1 and
           that stratified mid-session fallback
           rates are confounded by search
           duration
      D16       Unprobed error model strings        Ordering in Step 8 items           Yes, runner.py,
                killing the study on crashed 0-eval 2–3 and the advisor's              test_runner.py
                sessions. The architect: probe      NOTICE check
                NOTICE via ECONNREFUSED and
                check Model before Void,
                permanently ending the study on any
                other ID. Argon: check Void (0

https://gemini.google.com/app/f162db429ce1d6b0                                                              8/9
11/12/26, 10:52 AM                                      See attached instructions.



                Dispute                                Settled by                    Changes
                evaluations, crashed) before "model
                changed", also probe HTTP
                500/529 and existing transcripts for
                "<synthetic>", or pause rather
                than bricking the manifest

    D6, D7, D8 and Study 2's D11 to D15 stand as they were. Once D9-b, D10-a, D10-b, and D16 are
    applied, Study 1 and CS1.1 are converged.




https://gemini.google.com/app/f162db429ce1d6b0                                                     9/9

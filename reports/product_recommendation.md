# Product recommendation: investigate client reliability before redesigning the queue

**Independent synthetic case study. These are simulated findings, not Tamasha performance or achieved business impact.**

## Decision
Prioritise investigation of the version 1.1 / low-tier-device client timeout pathway. Confirm it with production traces and a reproducible device test before implementing a remote-flagged fix. Treat lobby discovery as a separate workstream: most users lost before joining did not attempt matchmaking at all.

## Evidence at a glance
| Question | Result | Interpretation |
|---|---|---|
| How many users activated? | 4,482 / 9,897 = 45.29%; Wilson 95% CI 44.31%–46.27% | 103 recent registrants excluded for incomplete 24h follow-up |
| Largest funnel loss? | 2,186 users from lobby to game joined; 27.05% of lobby users | 40.37% of all non-activated users; the location alone does not explain the cause |
| Did all lost lobby users hit a queue problem? | 1,207 had no attempt; 979 attempted but never joined | 55.22% of this loss cannot be attributed to an observed failed queue attempt |
| Is there a specific technical lead? | First-attempt failure: 153/815 (18.77%) for low-tier 1.1 vs 7/261 (2.68%) for low-tier 1.0 | Concurrent-period, one-attempt-per-user comparison; investigate client timeouts |
| Does the activation gap survive observable mix adjustment? | Low-tier 1.1: 35.34% vs 1.0: 45.49%; gap −10.15 pp, approximate 95% CI −15.71 to −4.59 pp | Week × channel standardisation; 99.68% common-support coverage within low-tier concurrent users |
| What about other devices? | Adjusted 1.1−1.0 gap: high −2.05 pp (CI −8.73 to 4.64), mid +2.48 pp (CI −2.22 to 7.18) | No similarly clear negative pattern in these simulated strata |
| Does a first failure always lose the user? | 93/276 (33.70%) first-failure users later activated within 24h | Existing recovery must be accounted for in opportunity estimates |
| Is activation related to later return? | D7: 893/4,212 (21.20%) activated vs 962/5,051 (19.05%) not activated | +2.16 pp association; latent intent causes both in the generator |

## Funnel detail
| Transition | Users before | Users after | Lost | Step conversion |
|---|---:|---:|---:|---:|
| Sign-up → onboarding | 9,897 | 8,464 | 1,433 | 85.52% |
| Onboarding → lobby | 8,464 | 8,082 | 382 | 95.49% |
| Lobby → game joined | 8,082 | 5,896 | 2,186 | 72.95% |
| Joined → started | 5,896 | 5,375 | 521 | 91.16% |
| Started → completed | 5,375 | 4,482 | 893 | 83.39% |

## What to do next
1. **Engineering diagnosis:** reproduce the client timeout in low-tier 1.1, compare request lifecycles with 1.0, and inspect cancellation, connection establishment and timeout handling. The simulated failure code is a lead, not a root-cause trace.
2. **Smallest corrective change:** if confirmed, fix the client request handling behind a stable remote flag. Keep queue ranking and opponent allocation unchanged so user-level randomisation has less interference.
3. **Instrumentation before exposure:** add assignment and exposure events, request IDs, client error codes, crash/ANR status, and retry linkage. Maintain server-normalised event time.
4. **Discovery research:** inspect lobby CTA visibility and conduct short usability sessions for the no-attempt path. Do not infer low motivation solely from absent events.
5. **Growth review:** paid social has 37.94% activation, but its device mix and latent intent differ. Acquisition budgets and channel ROI cannot be evaluated without cost and value data.

## Size of the opportunity — scenario, not forecast
There are 1,187 eligible low-tier 1.1 registrations. Closing 25%, 50% or 100% of the 10.15 pp adjusted observational gap corresponds to approximately 30, 60 or 121 additional activated users in this historical target population. These figures are **not measured uplift**, and the entire gap need not be caused by a repairable defect. Do not add this opportunity to overlapping channel/device estimates.

## Why not simply optimise time in queue?
Observed wait ends at matching, abandonment or technical failure. Duration bands therefore reflect competing outcomes and selection. They do not estimate the causal impact of making queues faster. Moreover, 1,207 lobby-only users never entered a queue.

## Why not launch a two-week activation A/B test immediately?
At baseline 35.30%, a 5 pp absolute effect needs approximately 1,476 users per arm at 80% power and two-sided α=.05. The simulated target receives only 27.0 users/day, implying roughly 110 enrolment days plus follow-up. A two-week test would be underpowered. Validate real target traffic and redesign the trial before launch; do not report an inconclusive short test as evidence of no effect.

## Evidence and scope
- `sql/04_overall_funnel.sql` → `data/dashboard_exports/overall_funnel.csv`.
- Notebook 02 section 4 → no-attempt versus unsuccessful-attempt decomposition.
- Notebook 02 sections 5–6 → `first_attempt_failure.csv` and `standardised_version_comparison.csv`.
- `sql/06_matchmaking_diagnostics.sql` → retry and queue analyses.
- `sql/08_activation_and_d7_retention.sql` → D7 numerator/denominator tables.
- Notebook 01 independently reproduces every user's funnel stage and tests five adversarial metric cases.

## Limitations
The data-generation mechanism deliberately creates the version/device issue and retention confounding. Confidence intervals reflect sampling under that mechanism, not uncertainty about a real app. There is one sampled user per game, so the dataset cannot support supply-side matchmaking, room occupancy or social-network conclusions. App upgrades, uninstall events, notification exposure and acquisition cost are not modelled. No causal claim, revenue improvement or completed experiment is made.

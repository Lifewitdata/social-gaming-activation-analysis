# Experiment brief: client reliability fix for low-tier devices

**Proposal only · synthetic planning baseline · no experiment has run.**

## Hypothesis and prerequisites
If production traces confirm a version 1.1 client timeout defect on low-tier devices, repairing that request lifecycle will increase 24-hour first-game activation without worsening crashes, queue latency or successful game completion.

First reproduce the defect, instrument assignment/exposure, verify a rollback flag and obtain real target traffic. Do not ship an unverified timeout extension merely because the simulated failure code says timeout.

## Design
| Item | Specification |
|---|---|
| Eligible population | Newly registered, low-tier-device users running the affected client; stable device classification at signup |
| Assignment | Persistent 50:50 user-level randomisation at registration, before onboarding; deterministic hash with experiment salt |
| Control | Existing client request handling |
| Treatment | Verified client request-lifecycle fix behind a remote flag; no queue ranking or opponent allocation change |
| Exposure | Flag evaluated and client branch active; log separately from assignment |
| Primary estimand | Intention-to-treat difference in 24h activation, treatment minus control |
| Primary denominator | All assigned eligible registrations with a complete 24-hour window, including non-exposed users |
| Primary numerator | Ordered, same-game activation contract in docs/metric_definitions.md |
| Secondary outcomes | First-attempt technical failure, attempt-to-join conversion, time to activation, D7 meaningful return |
| Planned segmentation | Device subtype and network quality; exploratory unless separately powered |

User-level assignment is appropriate only if the fix is client-local. If the change affects shared queues, host capacity or opponent allocation, revisit interference and use a cluster/switchback design with a newly calculated sample size.

## Sample size and traffic reality
- Planning baseline: 35.2991% (419/1,187 eligible target users).
- Minimum detectable effect: **+5 absolute percentage points**, approximately +14.2% relative; a business choice, not a measured effect.
- Two-sided significance level: 0.05; power: 0.80; allocation: 1:1.
- Approximate independent two-proportion design: **1,476 users per arm**, **2,952 total**.
- Target traffic estimate: 1,187 users across 44 complete enrolment days after rollout, or **26.98/day**.
- Estimated accrual: **110 days**, plus 24h for the last user's primary outcome and up to eight calendar days for full D7 follow-up.
- This is a feasibility warning, not a recommended 110-day unchanged product holdout. Real traffic may differ substantially.

Notebook 02 implements:
`n_per_arm = ceil((z_(1-alpha/2)*sqrt(2*pbar*(1-pbar)) + z_power*sqrt(p0*(1-p0)+p1*(1-p1)))^2 / (p1-p0)^2)`.

## Launch decision
**Do not launch a 14-day activation trial at the simulated traffic level.** Confirm real traffic first. If insufficient, either wait for enough eligible traffic, choose a larger business-relevant MDE before exposure, or pre-register a reliability-primary evaluation with a new power calculation and activation as a secondary outcome. Do not switch the primary metric after inspecting results. An urgent verified bug may instead need a monitored engineering rollout; report reliability evidence without inventing activation causality.

## Instrumentation required
`experiment_assigned`: experiment_id, user_id, assignment_timestamp, variant, eligibility snapshot.
`experiment_exposed`: experiment_id, user_id, variant, exposure_timestamp, client_build.
Join requests: attempt_id, request_id, error_code, timeout_budget, measured latency, network_type.
Crash/ANR logging: user_id, session_id, build, timestamp, error category.
Deduplicate immutable event IDs; retain assignment even after retries or later sessions.

## Guardrails and monitoring
Pre-launch thresholds below are proposed tolerances and require product/engineering agreement plus baseline telemetry:
- Crash-free user rate: no decrease larger than 0.5 pp.
- Successful-start-to-completion rate: no decrease larger than 1 pp.
- Queue latency: no increase larger than 10% in p95 among all terminal attempts, with outcomes shown separately.
- Request volume per assigned user: no increase larger than 10%, guarding against a retry storm.
Report estimates and uncertainty; monitor operational incidents immediately. The synthetic dataset lacks crash telemetry and request counts, so these guardrails are **not evaluated** here.

## Integrity and analysis plan
1. Verify sample-ratio balance at registration with a binomial/chi-square check; investigate SRM p<.001 and check assignment completeness. This is a diagnostic threshold, not a treatment success test.
2. Check A/A or pre-launch flag validation and event delivery parity by variant.
3. Predefine exclusions for internal/test accounts before assignment. Do not remove post-assignment users for low engagement or non-exposure.
4. Freeze the primary metric definition and sample-size plan. Report a two-sided 95% confidence interval for the difference in user activation proportions.
5. Analyse the fixed-horizon endpoint after full primary follow-up. Do not repeatedly peek and stop at the first significant result; any sequential design needs a separately specified boundary.
6. Report numerator, denominator, absolute pp difference, relative change, confidence interval, and guardrails. Distinguish inconclusive from no practically meaningful effect.
7. Use the predeclared practical-effect threshold and guardrails for the shipping decision. Statistical significance alone is insufficient; discuss smaller-than-5-pp estimates against costs rather than treating MDE as a significance threshold.
8. Read D7 only after maturity. Apply multiplicity control if secondary outcomes are promoted to confirmatory claims in a future pre-registration.

## Decision ownership
Engineering owns defect reproduction and rollback. Product owns the minimum worthwhile effect and tolerances. Analytics owns assignment QA, metric definitions, sizing, and the final readout.

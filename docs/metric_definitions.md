# Metric contract

All timestamps are timezone-aware UTC. Observation interval: `[2026-01-01 00:00, 2026-04-01 00:00)`. Registration is the cohort anchor, not installation.

| Metric | Numerator / calculation | Denominator / population | Caveat |
|---|---|---|---|
| Activation eligibility | signup_at + 24h ≤ observation end | all registrations | Do not count incomplete follow-up as failure |
| Activation | ordered sign-up → onboarding → lobby → join → start → complete; completion < signup+24h | eligible registrations | join/start/complete share user_id and game_id |
| Funnel stage reach | unique eligible users with a valid prefix ending at the stage | eligible registrations | not event counts; a later retry may qualify |
| Step conversion | users reaching stage k | users reaching stage k−1 | step one has no preceding conversion |
| Lost users | users at stage k−1 minus users at k | preceding stage | mutually exclusive furthest-stage losses |
| Time to activation | first qualifying completion − signup, in minutes | activated eligible registrations | conditional on success; report horizons too |
| Activation by horizon | activated before 15/60/360/1440 minutes | all 24h-eligible registrations | fixed cohort enables comparison |
| Join failure rate | attempts with outcome failed | first-day attempts from activation-eligible users | technical failure only; abandonment is separate |
| Queue abandonment rate | attempts with outcome abandoned | same first-day attempt population | descriptive, not causal effect of waiting |
| First-attempt failure | users whose first attempt failed | users with a first-day attempt | user-level outcome avoids pseudo-replication |
| Retry rate | users with >1 first-day attempts | users grouped by first-attempt outcome | can include a later session/game; not necessarily immediate retry |
| Recovery | users activated within 24h | users grouped by first-attempt outcome | observed recovery, not treatment effect |
| D7 eligibility | end of UTC calendar day signup_date+7 ≤ observation end | registrations | day 7 is a UTC calendar day, not hours 168–192 |
| D7 meaningful return | ≥1 lobby_viewed, game_started, or game_completed event on signup_date+7 | D7-eligible registrations | session open alone does not qualify |
| Weekly activation | activated eligible users in signup week | eligible users in same week | ISO Monday weeks; partial boundary weeks labelled |

## Additional analysis rules
- `activated` is a descriptive flag even for incomplete users; every headline metric filters `activation_eligible`.
- `d7_returned` is NULL for users without a complete D7 window; false means observed non-return.
- Session attributes describe the session, signup version describes acquisition context. They are equal in this simulation because upgrades are not simulated.
- `first_joined_at` and `first_started_at` are earliest valid prefix timestamps and can refer to different games. The completed path itself is always same-game.
- At exactly the 24-hour boundary a completion is excluded. This half-open convention is used in SQL, Python, and the tracking contract.
- Minimum segment display size: 100 users for headline comparisons; small strata are retained with counts for sensitivity analysis.
- Wilson 95% intervals describe binomial Monte Carlo uncertainty for user-level rates. Attempt-level rates are descriptive because repeated attempts are correlated.
- Standardisation uses shared week × channel strata within device tier during the concurrent rollout period. It cannot remove unmeasured intent or prove causality.
- Overlapping segment losses must not be summed. Distinct segment opportunity estimates are scenarios, not a forecast.

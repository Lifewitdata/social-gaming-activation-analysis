# Business problem: first-game activation

**Independent synthetic portfolio case study. No Tamasha internal data or affiliation.**

## Decision and audience
A product manager must decide which first-session friction to investigate before committing engineering capacity. The analyst must distinguish an onboarding loss, lack of intent to play, inability to join a game, and failure to complete a game.

Primary question: what prevents a new registrant from completing an ordered first-game funnel within 24 hours?

## Proposed app journey
Sign-up → onboarding completed → lobby viewed → game joined → game started → game completed.
A user may have several sessions, join attempts, or games. A valid completed path must join, start, and complete the **same game**. An unsuccessful first game must not prevent a later successful path from counting.

## Scope
- 10,000 synthetic registrations, January 1–March 31, 2026; observation ends April 1, 2026 at 00:00 UTC, exclusive.
- Primary population: registrations with a complete 24-hour observation window.
- Supporting outcomes: time to activation, first-attempt failure, retry recovery, D7 meaningful return.
- Dimensions: acquisition channel, device tier, app version, network type, signup week.
- No revenue, acquisition-cost, demographic, or monetisation conclusions: those fields are absent.

## Hypotheses to investigate
1. Technical matchmaking failures concentrate in a device/version combination.
2. Paid acquisition includes users with lower intent, affecting early conversion.
3. Long waits are associated with abandonment, but observed wait is jointly determined by success and abandonment.
4. Activated users return more often; activation is a useful segmentation signal, not automatically a causal driver.

## Decision standard
Prioritise a material, diagnosable issue with a measurable intervention. Separate the biggest absolute funnel loss from the most actionable cause. Support recommendations with counts, denominators, comparable-period comparisons, uncertainty, and an experiment plan.

## Stakeholders
Product: prioritisation and success criteria. Engineering: failure codes and instrumentation. Growth: channel mix. Analytics: metric ownership, data-quality checks, experiment evaluation.

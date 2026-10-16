# FIRST GAME — Social Gaming Activation Analysis

**A SQL-first product analytics case study: diagnose why new users do not complete their first game.**

Python · PostgreSQL · Tableau · Funnel analysis · Cohorts · Experiment design

> **Synthetic portfolio project.** All users, events and findings are simulated. This is not an analysis of Tamasha internal data and is not affiliated with Tamasha. No experiment or real business uplift is claimed.

![Activation overview](dashboards/screenshots/dashboard_01_overview.png)

## Decision in one minute
Of 10,000 registrations, 9,897 have a complete 24-hour observation window. **4,482 activate (45.29%)**. The largest loss is from lobby view to game joined: **2,186 users**.

That loss has two distinct paths: **1,207 never attempt a match**, while **979 attempt but never join**. A queue-only recommendation would miss most of the first group.

The strongest technical investigation lead is **low-tier devices on version 1.1**: concurrent-period first-attempt failures are **18.77% (153/815)** versus **2.68% (7/261)** on version 1.0. The low-tier activation gap remains **−10.15 pp** after standardising to shared signup-week × acquisition-channel strata. These relationships were deliberately generated; they demonstrate diagnosis, not a real company defect.

**Recommendation:** reproduce and investigate the client-timeout pathway, then evaluate a targeted reliability fix. Investigate lobby discovery separately. The proposed activation experiment is not feasible as a two-week trial at the simulated target traffic: approximately **1,476 users per arm** and **110 days of enrolment** are needed for a 5 pp MDE.

Read [the recommendation](reports/product_recommendation.md) and [the experiment brief](reports/experiment_brief.md).

## What is included
- 10,000 synthetic users, 57,332 sessions, 45,847 queue attempts and 34,384 game participations across 90 days.
- 281,652 raw event rows, 150 quarantined rows, and 281,502 validated events.
- Eight PostgreSQL scripts with ordered, time-bounded, same-game funnel logic.
- Two executed notebooks containing displayed tables, charts, independent checks and detailed interpretation.
- Fifteen SQL-derived CSV exports plus additional statistical comparison exports.
- A packaged Tableau workbook containing three dashboard pages, nine worksheets and embedded CSV data.
- Three Python-rendered dashboard previews and eight notebook charts.
- Event tracking plan, data dictionary, metric contract, simulation assumptions, decision memo and experiment brief.

## Repository structure
```text
social-gaming-activation-analysis/
├── README.md
├── requirements.txt
├── .gitignore
├── data/
│   ├── raw/                    # 5 source CSVs + reproducibility manifest
│   ├── processed/              # validated CSVs, quarantine and audit evidence
│   └── dashboard_exports/      # SQL results and statistical comparisons
├── docs/
│   ├── business_problem.md
│   ├── metric_definitions.md
│   ├── tracking_plan.csv
│   ├── data_dictionary.csv
│   └── simulation_assumptions.md
├── src/
│   ├── generate_data.py
│   ├── validate_data.py
│   └── load_postgres.py
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_data_quality_checks.sql
│   ├── 03_build_user_activation.sql
│   ├── 04_overall_funnel.sql
│   ├── 05_segment_funnels.sql
│   ├── 06_matchmaking_diagnostics.sql
│   ├── 07_time_to_activation.sql
│   └── 08_activation_and_d7_retention.sql
├── notebooks/
│   ├── 01_data_quality_and_eda.ipynb
│   └── 02_dropoff_diagnostics.ipynb
├── dashboards/
│   ├── activation_dashboard.twbx
│   └── screenshots/
└── reports/
    ├── product_recommendation.md
    └── experiment_brief.md
```

## Start here — no database required to review
1. Read this README and `docs/metric_definitions.md`.
2. Open notebook 01 to inspect data quality and funnel verification.
3. Open notebook 02 for the diagnostic argument, uncertainty and experiment sizing.
4. Read the recommendation and experiment brief.
5. Open the three dashboard PNGs for a quick overview, or open the TWBX in Tableau Desktop/Public Desktop.

The notebooks contain saved outputs. GitHub, VS Code and Jupyter can display them. The bundled exports support rerunning the notebooks without a running database.

## Reproduce the analysis
Use Python 3.12 and a virtual environment. Commands below run from this repository's root.

```bash
python -m venv .venv
# macOS/Linux:
source .venv/bin/activate
# Windows PowerShell alternative:
# .venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

### 1. Regenerate and validate the source data
```bash
python src/generate_data.py --users 10000 --seed 2026
python src/validate_data.py
```
Raw input stays unchanged during validation. Rejected events retain a reason. `data/raw/manifest.json` records checksums, seed and cutoff. Optional nulls are documented rather than automatically dropped.

### 2. Execute PostgreSQL analytics
Create an empty development database using your PostgreSQL administrator tools. PostgreSQL 16+ is the intended server target; the delivered queries were executed on PostgreSQL 18.6 through PGlite.

```bash
# Replace with your own development database credentials; do not commit this value.
export DATABASE_URL='postgresql://USER:PASSWORD@localhost:5432/gaming_analytics'
python src/load_postgres.py --reset-project-schema
```

Windows PowerShell uses `$env:DATABASE_URL = 'postgresql://USER:PASSWORD@localhost:5432/gaming_analytics'` before running the same Python command.

The loader replaces **only** the dedicated `gaming_activation` schema, loads processed CSVs using COPY, executes SQL 01–08, checks violations, and exports analytical tables in a transaction. The explicit `--reset-project-schema` flag is required. Do not point this at a shared production database.

For manual SQL review, execute 01 to create the schema, load the five clean tables in the loader's order, then execute 02–08. The loader is the simpler complete path.

### 3. Run the notebooks
Open in VS Code/Jupyter and choose **Run All**, notebook 01 then notebook 02. Install JupyterLab separately if you prefer its browser interface. Alternatively, the included nbclient dependency supports a script:

```python
from pathlib import Path
import nbformat
from nbclient import NotebookClient
root = Path.cwd()
for path in sorted((root / 'notebooks').glob('*.ipynb')):
    book = nbformat.read(path, as_version=4)
    NotebookClient(book, timeout=300, kernel_name='python3',
                   resources={'metadata': {'path': str(root)}}).execute()
    nbformat.write(book, path)
```
If your environment does not have a Python kernel registered, run `python -m ipykernel install --user --name python3` first. The notebooks detect whether they run from the project root or the notebooks folder.

Notebook 02's final code cells rebuild the packaged Tableau workbook and the three dashboard previews. The recommendation memo and experiment brief are narrative snapshots of seed 2026; review their numbers if you change the simulation.

## Analysis map
| Question | Implementation | Output |
|---|---|---|
| Can we trust the telemetry? | validator, SQL 02, notebook 01 | quarantine, validation reports, independent checks |
| Who activated on a valid path? | SQL 03 | one row per user in `user_activation.csv` |
| Where is the largest drop? | SQL 04 | overall funnel and weekly activation |
| Which segments differ? | SQL 05 | segment funnels and comparable-period strata |
| Why do joins fail? | SQL 06, notebook 02 | first-attempt failures, retry recovery, wait outcomes |
| How quickly do users activate? | SQL 07 | conditional timing and all-user horizon rates |
| Is activation associated with return? | SQL 08 | mature D7 cohorts and segment comparisons |
| What should be tested? | notebook 02 and reports | adjusted comparisons, scenarios, power and feasibility |

## Metric decisions that prevent misleading results
- Count users for the funnel, not events or sessions.
- Evaluate every candidate game path. Join, start and complete must share a game ID; a failed first game does not invalidate a later successful one.
- Use chronological events within `[signup, signup + 24h)`.
- Exclude incomplete observation windows from denominators; never treat censored D7 outcomes as false.
- Keep technical failures, abandonment and no-attempt behaviour separate.
- Use first-attempt user-level samples for uncertainty rather than treating repeated attempts as independent people.
- Compare versions during concurrent rollout weeks and account for channel/device mix.
- Treat observed retention relationships and adjusted gaps as associations.
- Do not claim real uplift from synthetic data or a proposed experiment.

## Tableau package and validation boundary
`dashboards/activation_dashboard.twbx` contains three native dashboard definitions and nine bar-chart worksheets, each connected to an embedded CSV. Rates use `SUM(Numerator)/SUM(Denominator)`; the funnel uses `SUM(Numerator)`. The workbook uses snapshot analytical exports, not a live database connection. It does **not** provide linked global cohort filters across all nine sources. Use the supplied user-level table to build a unified filtering model if extending the dashboard.

The package passed ZIP integrity, embedded-file references, worksheet/dashboard counts, and validation against Tableau's official 2026.1 TWB XSD. The schema's auxiliary `user` and `xml` namespace imports were resolved locally. **Tableau Desktop is unavailable in the build environment, so native opening, rendering and interactions have not been verified.** Open and save it in your installed Tableau version before publishing. The files under `dashboards/screenshots/` are explicitly labelled Python-rendered previews/charts, not screenshots of Tableau running.

Official format references:
- [Packaged workbooks](https://help.tableau.com/current/pro/desktop/en-gb/save_savework_packagedworkbooks.htm)
- [Tableau document schemas](https://github.com/tableau/tableau-document-schemas)

## Verification performed
- Raw-source SHA-256 checksums and row-count reconciliation.
- Python validation of keys, ownership, chronology, quarantine and event/game reconciliation.
- All eight SQL scripts executed in **PostgreSQL 18.6 via PGlite 0.5.10**; all ten semantic DQ queries return zero violations.
- Unique user activation table; no invalid activation durations or non-null censored D7 outcomes.
- Independent Python state-machine reconstruction matches SQL for **all 10,000 users**.
- Five adversarial fixtures cover same-game completion, cross-game rejection, retry success, the exact 24-hour boundary, and out-of-order start events.
- Both notebooks executed sequentially in an in-process IPython interpreter with outputs captured. A separate Jupyter TCP kernel could not run in the build environment; the analysis cells themselves executed successfully.
- Tableau XML/package checks and visual inspection of rendered dashboard previews.

The psycopg server-loading route is supplied but was not exercised against a separately installed PostgreSQL server; execution evidence is from the PostgreSQL engine embedded in PGlite. Audit results are in `data/processed/`.

## Limitations
The generator plants the main version/device pattern. Latent intent affects both activation and return; activation itself does not cause retention in the simulator. Only one sampled participant is generated per game. Supply, occupancy, social spillovers, app upgrades, spend, revenue and crash telemetry are outside scope. This project demonstrates analytical method and product judgement, not business knowledge from private data.

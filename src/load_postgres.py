"""Load validated CSVs and execute all analyses in a dedicated PostgreSQL schema.

DATABASE_URL must name a development database. Pass --reset-project-schema to
explicitly replace gaming_activation; all other schemas are left untouched.
"""
from pathlib import Path
import argparse
import csv
import json
import os
import psycopg

ROOT=Path(__file__).resolve().parents[1]
VIEWS=['dq_checks','user_activation','overall_funnel','weekly_activation','segment_funnels',
       'version_strata','first_day_attempts','matchmaking_summary','wait_outcomes',
       'retry_recovery','activation_timing','activation_horizons','retention_comparison',
       'retention_cohorts','retention_segments']

def run():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reset-project-schema',action='store_true')
    args=p.parse_args()
    if not args.reset_project_schema: p.error('Pass --reset-project-schema to allow replacement of the project schema.')
    url=os.environ.get('DATABASE_URL')
    if not url: p.error('Set DATABASE_URL to your PostgreSQL development database connection string.')
    validation=json.loads((ROOT/'data/processed/validation_report.json').read_text())
    if not validation['passed']: raise ValueError('Data validation did not pass; run validate_data.py.')
    out=ROOT/'data/dashboard_exports'; out.mkdir(parents=True,exist_ok=True)
    scripts=sorted((ROOT/'sql').glob('*.sql'))
    # One transaction: failed loads or analyses roll back the schema replacement.
    with psycopg.connect(url) as conn, conn.cursor() as cur:
        cur.execute(scripts[0].read_text())
        for name in ['users','sessions','matchmaking_attempts','game_participation','events']:
            path=ROOT/'data/processed'/f'{name}.csv'
            with cur.copy(f'COPY gaming_activation.{name} FROM STDIN WITH (FORMAT CSV, HEADER TRUE)') as copy:
                with path.open('rb') as f:
                    while chunk:=f.read(1024*1024): copy.write(chunk)
        manifest=json.loads((ROOT/'data/raw/manifest.json').read_text())
        cur.execute('UPDATE gaming_activation.analysis_config SET observation_end=%s',(manifest['observation_end_exclusive'],))
        cur.execute('ANALYZE')
        for script in scripts[1:]: cur.execute(script.read_text())
        cur.execute('SELECT check_name,violations FROM gaming_activation.dq_checks WHERE violations>0')
        failures=cur.fetchall()
        if failures: raise ValueError(f'SQL quality checks failed: {failures}')
        for name in VIEWS:
            with (out/f'{name}.csv').open('wb') as f:
                with cur.copy(f'COPY (SELECT * FROM gaming_activation.{name}) TO STDOUT WITH (FORMAT CSV, HEADER TRUE)') as copy:
                    for data in copy: f.write(data)
    print(f'Exported {len(VIEWS)} analytical tables to {out}')

if __name__=='__main__': run()

"""Validate table integrity; quarantine bad events without modifying raw files."""
from pathlib import Path
import json
import pandas as pd

ROOT=Path(__file__).resolve().parents[1]
DATES={'users':['signup_at'],'sessions':['session_start','session_end'],
       'events':['event_timestamp'],'matchmaking_attempts':['queue_entered_at','queue_exited_at'],
       'game_participation':['joined_at','started_at','ended_at']}
KEYS={'users':['user_id'],'sessions':['session_id'],'events':['event_id'],
      'matchmaking_attempts':['attempt_id'],'game_participation':['game_id','user_id']}

def read_tables(folder):
    tables={k:pd.read_csv(folder/f'{k}.csv',dtype={'app_version':str,'signup_app_version':str}) for k in DATES}
    for k,cols in DATES.items():
        for col in cols: tables[k][col]=pd.to_datetime(tables[k][col],utc=True)
    return tables

def validate():
    tables=read_tables(ROOT/'data/raw'); manifest=json.loads((ROOT/'data/raw/manifest.json').read_text())
    cutoff=pd.Timestamp(manifest['observation_end_exclusive'])
    u=tables['users']; s=tables['sessions']; ev=tables['events'].copy(); a=tables['matchmaking_attempts']; g=tables['game_participation']
    checks=[]
    def check(name,condition):
        ok=bool(condition); checks.append({'check':name,'passed':ok}); assert ok,name
    for k,df in tables.items():
        if k!='events':
            check(k+'_unique_key',not df.duplicated(KEYS[k]).any())
            check(k+'_nonnull_key',not df[KEYS[k]].isna().any().any())
        if k not in ['users','events']: check(k+'_valid_user',df.user_id.isin(u.user_id).all())
    check('registration_in_window',u.signup_at.ge(pd.Timestamp(manifest['observation_start'])).all() and u.signup_at.lt(cutoff).all())
    check('session_order',s.session_end.ge(s.session_start).all() and s.session_end.le(cutoff).all())
    check('session_after_signup',s.session_start.ge(s.user_id.map(u.set_index('user_id').signup_at)).all())
    for name,df in [('matchmaking_attempts',a),('game_participation',g)]:
        check(name+'_session_owner',df.user_id.eq(df.session_id.map(s.set_index('session_id').user_id)).all())
    check('queue_order',a.queue_exited_at.dropna().ge(a.loc[a.queue_exited_at.notna(),'queue_entered_at']).all())
    check('pending_queue_null_exit',a.outcome.eq('pending').eq(a.queue_exited_at.isna()).all())
    check('attempt_outcomes',a.outcome.isin(['joined','failed','abandoned','pending']).all())
    check('failed_reason',a.loc[a.outcome.eq('failed'),'failure_reason'].notna().all())
    check('game_attempt_owner',g.user_id.eq(g.attempt_id.map(a.set_index('attempt_id').user_id)).all())
    check('game_attempt_id',g.game_id.eq(g.attempt_id.map(a.set_index('attempt_id').game_id)).all())
    check('game_start_order',g.started_at.dropna().ge(g.loc[g.started_at.notna(),'joined_at']).all())
    check('game_end_order',g.ended_at.dropna().ge(g.loc[g.ended_at.notna(),'started_at']).all())
    check('completed_has_end',g.loc[g.completion_status.eq('completed'),'ended_at'].notna().all())
    reasons=pd.Series('',index=ev.index)
    def flag(mask,label):
        nonlocal reasons
        reasons.loc[mask]=reasons.loc[mask]+label+';'
    flag(ev.duplicated('event_id',keep='first'),'duplicate_event_id')
    flag(~ev.user_id.isin(u.user_id),'unknown_user')
    flag(ev.event_timestamp.lt(ev.user_id.map(u.set_index('user_id').signup_at)),'before_signup')
    flag(ev.event_timestamp.ge(cutoff),'outside_observation')
    flag(ev[['event_id','user_id','session_id','event_name','event_timestamp']].isna().any(axis=1),'missing_required')
    flag(~ev.user_id.eq(ev.session_id.map(s.set_index('session_id').user_id)),'session_owner_mismatch')
    flag(ev.event_timestamp.lt(ev.session_id.map(s.set_index('session_id').session_start)) | ev.event_timestamp.gt(ev.session_id.map(s.set_index('session_id').session_end)),'outside_session')
    known=['session_started','sign_up','onboarding_completed','lobby_viewed','matchmaking_started','game_joined','game_started','game_completed','game_exited','queue_abandoned','game_join_failed']
    flag(~ev.event_name.isin(known),'unknown_event')
    flag(ev.event_name.isin(['matchmaking_started','game_joined','game_join_failed','queue_abandoned','game_started','game_completed','game_exited']) & ev.attempt_id.isna(),'missing_attempt_id')
    flag(ev.event_name.isin(['game_joined','game_started','game_completed','game_exited']) & ev.game_id.isna(),'missing_game_id')
    mask=ev.attempt_id.notna(); flag(mask & ~ev.user_id.eq(ev.attempt_id.map(a.set_index('attempt_id').user_id)),'attempt_owner_mismatch')
    game_owners=g.set_index('game_id').user_id
    flag(ev.game_id.notna() & ~ev.user_id.eq(ev.game_id.map(game_owners)),'game_owner_mismatch')
    rejected=ev[reasons.ne('')].copy(); rejected['rejection_reason']=reasons[reasons.ne('')]
    clean=ev[reasons.eq('')].sort_values(['user_id','event_timestamp','event_id']).copy()
    tables['events']=clean
    check('clean_events_unique',not clean.event_id.duplicated().any())
    check('clean_events_valid_user',clean.user_id.isin(u.user_id).all())
    check('signup_event_coverage',set(clean.loc[clean.event_name.eq('sign_up'),'user_id'])==set(u.user_id))
    check('raw_reconciliation',len(ev)==len(clean)+len(rejected))
    check('completed_event_reconciliation',clean.event_name.eq('game_completed').sum()==g.completion_status.eq('completed').sum())
    out=ROOT/'data/processed'; out.mkdir(parents=True,exist_ok=True)
    for name,df in tables.items():
        target=out/f'{name}.csv'; temporary=out/f'{name}.csv.tmp'
        df.to_csv(temporary,index=False,date_format='%Y-%m-%dT%H:%M:%S.%fZ')
        temporary.replace(target)
    rejected.to_csv(out/'rejected_events.csv',index=False,date_format='%Y-%m-%dT%H:%M:%S.%fZ')
    report={'passed':all(c['passed'] for c in checks),'checks':checks,'raw_event_rows':len(ev),'clean_event_rows':len(clean),'quarantined_rows':len(rejected),'reason_counts':rejected.rejection_reason.str.split(';').explode().value_counts().drop('',errors='ignore').to_dict()}
    (out/'validation_report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:v for k,v in report.items() if k!='checks'},indent=2))
    return report

if __name__=='__main__': validate()

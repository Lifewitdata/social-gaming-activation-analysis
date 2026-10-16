"""Generate reproducible SYNTHETIC product telemetry. No real user data.

Run from any directory: python src/generate_data.py --seed 2026 --users 10000
See docs/simulation_assumptions.md for the intentionally planted mechanisms.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
START = pd.Timestamp('2026-01-01T00:00:00Z')
CUTOFF = pd.Timestamp('2026-04-01T00:00:00Z')


def generate(n=10000, seed=2026):
    rng = np.random.default_rng(seed)
    users, sessions, events, attempts, games = [], [], [], [], []
    counters = {'event': 0, 'session': 0, 'attempt': 0, 'game': 0}

    def ident(kind):
        counters[kind] += 1
        return f'{kind[:1].upper()}{counters[kind]:08d}'

    def event(uid, sid, name, when, aid=None, gid=None):
        if when < CUTOFF:
            events.append(dict(event_id=ident('event'), user_id=uid, session_id=sid,
                               event_name=name, event_timestamp=when, attempt_id=aid, game_id=gid))

    for i in range(n):
        uid = f'U{i+1:06d}'
        signup = START + pd.Timedelta(seconds=int(rng.integers(0, 90*86400)))
        channel = str(rng.choice(['organic', 'referral', 'paid_social', 'influencer'], p=[.32,.18,.35,.15]))
        tier = str(rng.choice(['low', 'mid', 'high'], p=[.40,.43,.17] if channel=='paid_social' else [.25,.48,.27]))
        version = '1.1' if signup >= START+pd.Timedelta(days=45) and rng.random()<.76 else '1.0'
        users.append(dict(user_id=uid, signup_at=signup, acquisition_channel=channel,
                          device_tier=tier, signup_app_version=version))
        # Intent is deliberately latent; it confounds activation/retention comparisons.
        intent = float(np.clip(rng.beta(3,2)+({'referral':.14,'organic':.05,'paid_social':-.10,'influencer':-.03}[channel]),.05,.98))
        onboarded = False
        activated = False
        day_offsets = [0]
        if rng.random()<.35:
            day_offsets.append(float(rng.uniform(.05,.85)))
        for day in range(1,31):
            if rng.random() < .04 + .38*intent*np.exp(-day/25):
                day_offsets.append(day+float(rng.uniform(0,.5)))
        for offset in sorted(day_offsets):
            t = signup + pd.Timedelta(days=offset)
            if t >= CUTOFF: continue
            sid = ident('session')
            network = str(rng.choice(['wifi','mobile_good','mobile_poor'], p=[.28,.44,.28] if tier=='low' else [.45,.45,.10]))
            begin = t
            event(uid,sid,'session_started',t)
            if offset==0: event(uid,sid,'sign_up',t)
            t += pd.Timedelta(seconds=int(rng.integers(10,90)))
            if not onboarded and rng.random() < .74+.18*intent-(.12 if channel=='paid_social' else 0):
                onboarded = True
                event(uid,sid,'onboarding_completed',t)
            if onboarded and rng.random()<.93:
                t += pd.Timedelta(seconds=int(rng.integers(5,40)))
                event(uid,sid,'lobby_viewed',t)
                if rng.random() < .62+.28*intent:
                    for retry in range(3):
                        aid = ident('attempt')
                        t += pd.Timedelta(seconds=5)
                        entered = t
                        event(uid,sid,'matchmaking_started',entered,aid)
                        # Competing events: match, abandonment, technical failure.
                        match = float(rng.exponential(25 if network!='mobile_poor' else 45)+3)
                        patience = float(rng.exponential(22+90*intent)+8)
                        technical = float(rng.uniform(3,25)) if rng.random() < (.25 if version=='1.1' and tier=='low' else .025)+(.07 if network=='mobile_poor' else 0) else 1e9
                        wait = min(match,patience,technical)
                        t += pd.Timedelta(seconds=wait)
                        if t >= CUTOFF:
                            attempts.append(dict(attempt_id=aid,user_id=uid,session_id=sid,
                                queue_entered_at=entered,queue_exited_at=None,outcome='pending',failure_reason=None,game_id=None))
                            break
                        outcome = 'joined' if wait==match else ('abandoned' if wait==patience else 'failed')
                        gid = ident('game') if outcome=='joined' else None
                        reason = ('client_timeout' if version=='1.1' and tier=='low' else 'network_error') if outcome=='failed' else None
                        attempts.append(dict(attempt_id=aid,user_id=uid,session_id=sid,
                            queue_entered_at=entered,queue_exited_at=t,outcome=outcome,failure_reason=reason,game_id=gid))
                        event(uid,sid,{'joined':'game_joined','abandoned':'queue_abandoned','failed':'game_join_failed'}[outcome],t,aid,gid)
                        if outcome=='joined':
                            joined=t
                            began=None
                            end=None
                            status='not_started'
                            if rng.random() < .90-(.08 if tier=='low' and version=='1.1' else 0):
                                candidate=t+pd.Timedelta(seconds=int(rng.integers(4,35)))
                                if candidate<CUTOFF:
                                    began=candidate
                                    event(uid,sid,'game_started',began,aid,gid)
                                    t=began+pd.Timedelta(seconds=int(rng.integers(180,900)))
                                    status='completed' if rng.random()<.69+.22*intent-(.09 if network=='mobile_poor' else 0) else 'exited'
                                    if t<CUTOFF:
                                        end=t
                                        event(uid,sid,'game_completed' if status=='completed' else 'game_exited',end,aid,gid)
                                        if status=='completed' and end<signup+pd.Timedelta(days=1): activated=True
                                    else: status='in_progress'
                            games.append(dict(game_id=gid,user_id=uid,session_id=sid,attempt_id=aid,
                                joined_at=joined,started_at=began,ended_at=end,completion_status=status))
                            break
                        if rng.random()>.42: break
            finish = min(t+pd.Timedelta(seconds=10),CUTOFF)
            sessions.append(dict(session_id=sid,user_id=uid,session_start=begin,session_end=finish,
                                 app_version=version,network_type=network))
    tables = {k:pd.DataFrame(v) for k,v in [('users',users),('sessions',sessions),('events',events),('matchmaking_attempts',attempts),('game_participation',games)]}
    # Observability exercise: preserve raw faults; validation quarantines them.
    ev=tables['events']
    faults=[]
    for idx in rng.choice(len(ev),size=100,replace=False): faults.append(ev.iloc[idx].to_dict())
    for j in range(30):
        row=ev.iloc[j].to_dict(); row['event_id']=f'BADTIME{j:04d}'; row['event_timestamp']=START-pd.Timedelta(days=1); faults.append(row)
    for j in range(20):
        row=ev.iloc[j+30].to_dict(); row['event_id']=f'BADUSER{j:04d}'; row['user_id']='UNKNOWN'; faults.append(row)
    tables['events']=pd.concat([ev,pd.DataFrame(faults)],ignore_index=True).sample(frac=1,random_state=seed).reset_index(drop=True)
    raw=ROOT/'data/raw'; raw.mkdir(parents=True,exist_ok=True)
    manifest={'synthetic':True,'seed':seed,'requested_users':n,'observation_start':START.isoformat(),
              'observation_end_exclusive':CUTOFF.isoformat(),'timezone':'UTC','injected_faults':{'duplicate_event_rows':100,'before_signup':30,'unknown_user':20},'files':{}}
    for name,df in tables.items():
        path=raw/f'{name}.csv'; df.to_csv(path,index=False,date_format='%Y-%m-%dT%H:%M:%S.%fZ')
        manifest['files'][name]={'rows':len(df),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    (raw/'manifest.json').write_text(json.dumps(manifest,indent=2))
    print(json.dumps({k:len(v) for k,v in tables.items()},indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--users',type=int,default=10000); parser.add_argument('--seed',type=int,default=2026)
    args=parser.parse_args()
    if args.users<100: parser.error('--users must be at least 100')
    generate(args.users,args.seed)

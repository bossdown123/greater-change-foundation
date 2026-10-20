"""Normalization, attribution, immutable history, and rollback against the migration SQL."""
from pathlib import Path
import sqlite3
root=Path(__file__).resolve().parents[2]
db=sqlite3.connect(':memory:')
db.execute('PRAGMA foreign_keys=ON')
for name in ['initialize','admin_content','programmes']:
    db.executescript((root/'infra/sqitch/deploy'/f'{name}.sql').read_text())
db.execute("INSERT INTO events(id,title,created_at,updated_at) VALUES('legacy-event','Before accounts','then','then')")
db.commit()
db.executescript((root/'infra/sqitch/deploy/identity_audit.sql').read_text())
assert db.execute("SELECT created_by,updated_by FROM events_attribution").fetchone()==('legacy','legacy')
def rejected(sql):
    try: db.execute(sql)
    except sqlite3.IntegrityError: return
    raise AssertionError(sql)
rejected("UPDATE events SET title='untracked'")
def begin(action,actor='bootstrap'):
    db.execute('INSERT INTO audit_actions VALUES(?,?,?,?,?,?,?)',(action,actor,'test','events','e','Event','now'))
    db.execute('INSERT INTO audit_context VALUES(1,?)',(action,))
def end():
    db.execute('DELETE FROM audit_context')
    db.commit()
begin('setup')
db.execute("INSERT INTO actors VALUES('u','user','','now')")
db.execute("INSERT INTO users VALUES('u','owner@example.test','Owner','private-password-hash','administrator',1,1,'now','now')")
end()
begin('create','u')
db.execute("INSERT INTO events(id,title,created_at,updated_at) VALUES('e','Event','now','now')")
db.execute("INSERT INTO event_dates VALUES('e',0,'2026-10-20')")
end()
assert db.execute("SELECT created_by,updated_by FROM events_attribution WHERE record_id='e'").fetchone()==('u','u')
assert db.execute("SELECT COUNT(*) FROM audit_rows WHERE action_id='create'").fetchone()[0]==2
assert not db.execute("SELECT 1 FROM audit_values WHERE column_name='password_hash' OR old_value='private-password-hash' OR new_value='private-password-hash'").fetchall()
begin('update','bootstrap')
db.execute("UPDATE events SET title='Updated' WHERE id='e'")
end()
assert db.execute("SELECT created_by,updated_by FROM events_attribution WHERE record_id='e'").fetchone()==('u','bootstrap')
assert db.execute("SELECT old_value,new_value FROM audit_values v JOIN audit_rows r ON r.id=v.row_id WHERE r.action_id='update' AND column_name='title'").fetchone()==('Event','Updated')
begin('failed','u')
db.execute("UPDATE events SET title='Must roll back' WHERE id='e'")
try: db.execute("INSERT INTO event_dates VALUES('missing',0,'2026-10-20')")
except sqlite3.IntegrityError: db.rollback()
assert db.execute("SELECT title FROM events WHERE id='e'").fetchone()[0]=='Updated'
assert not db.execute("SELECT 1 FROM audit_actions WHERE id='failed'").fetchall()
assert db.execute('SELECT COUNT(*) FROM audit_context').fetchone()[0]==0
rejected("DELETE FROM audit_actions")
rejected("UPDATE audit_values SET new_value='forged'")
begin('disable','u')
rejected("UPDATE users SET active=0 WHERE id='u'")
db.rollback()
begin('remove','u')
db.execute("DELETE FROM events WHERE id='e'")
end()
assert db.execute("SELECT COUNT(*) FROM audit_rows WHERE action_id='remove'").fetchone()[0]==2
assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
db.executescript((root/'infra/sqitch/revert/identity_audit.sql').read_text())
assert db.execute("SELECT title FROM events WHERE id='legacy-event'").fetchone()[0]=='Before accounts'
assert db.execute('SELECT version FROM gcf_schema').fetchone()[0]==3
print('PASS: legacy attribution, guarded writes, per-row before/after history, secret exclusion, atomic rollback, identity retention, and migration reversal')

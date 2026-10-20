"""Schema constraints and reversibility, using the same deploy SQL as production."""
from pathlib import Path
import sqlite3
root=Path(__file__).resolve().parents[2]
db=sqlite3.connect(':memory:')
db.execute('PRAGMA foreign_keys=ON')
for name in ['initialize','admin_content']:
    db.executescript((root/'infra/sqitch/deploy'/f'{name}.sql').read_text())
def reject(sql, args=()):
    try: db.execute(sql,args)
    except sqlite3.IntegrityError: return
    raise AssertionError('Constraint did not reject invalid data')
db.execute("INSERT INTO events(id,title,created_at,updated_at) VALUES('e','Event','now','now')")
db.execute("INSERT INTO event_dates VALUES('e',0,'2026-10-20')")
reject("INSERT INTO event_dates VALUES('e',1,'2026-10-20')")
reject("INSERT INTO event_dates VALUES('missing',0,'2026-10-20')")
db.execute("INSERT INTO field_definitions VALUES('f','Participants','number')")
reject("INSERT INTO field_definitions VALUES('f2','Participants','number')")
reject("INSERT INTO event_field_values(event_id,field_id,position,text_value) VALUES('e','f',0,'twelve')")
db.execute("INSERT INTO event_field_values(event_id,field_id,position,number_value) VALUES('e','f',0,12)")
reject("UPDATE field_definitions SET kind='text' WHERE id='f'")
reject("UPDATE event_field_values SET number_value=NULL,text_value='twelve' WHERE event_id='e'")
db.execute("DELETE FROM events WHERE id='e'")
assert db.execute('SELECT count(*) FROM event_dates').fetchone()[0]==0
assert db.execute('SELECT count(*) FROM event_field_values').fetchone()[0]==0
assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
for name in ['admin_content','initialize']:
    db.executescript((root/'infra/sqitch/revert'/f'{name}.sql').read_text())
assert not db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").fetchall()
print('PASS: normalized keys, types, referential integrity, cascades, and migration reversal')

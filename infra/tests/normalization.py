"""Schema constraints and reversibility, using the same deploy SQL as production."""
from pathlib import Path
import sqlite3
root=Path(__file__).resolve().parents[2]
db=sqlite3.connect(':memory:')
db.execute('PRAGMA foreign_keys=ON')
for name in ['initialize','admin_content','programmes']:
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
db.execute("INSERT INTO initiatives VALUES('i','Initiative','Story','now','now')")
db.execute("INSERT INTO campaigns(id,title,currency,created_at,updated_at) VALUES('c','Campaign','JMD','now','now')")
db.execute("INSERT INTO initiative_events VALUES('i','e',0)")
db.execute("INSERT INTO campaign_events VALUES('c','e',0)")
db.execute("INSERT INTO campaign_initiatives VALUES('c','i',0)")
db.execute("INSERT INTO newsletters VALUES('n','News','Subject','Intro','Body','now','now')")
db.execute("INSERT INTO newsletter_items VALUES('ni','n',0,'events')")
reject("INSERT INTO newsletter_initiative_items VALUES('ni','initiatives','i')")
db.execute("INSERT INTO newsletter_event_items VALUES('ni','events','e')")
db.execute("INSERT INTO newsletter_items VALUES('ni2','n',1,'events')")
reject("INSERT INTO newsletter_event_items VALUES('ni2','events','e')")
db.execute("DELETE FROM newsletter_items WHERE id='ni2'")
db.execute("DELETE FROM events WHERE id='e'")
assert db.execute('SELECT count(*) FROM event_dates').fetchone()[0]==0
assert db.execute('SELECT count(*) FROM event_field_values').fetchone()[0]==0
assert db.execute('SELECT count(*) FROM newsletter_items').fetchone()[0]==0
assert db.execute('SELECT count(*) FROM initiatives').fetchone()[0]==1
assert db.execute('SELECT count(*) FROM campaigns').fetchone()[0]==1
assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
for name in ['programmes','admin_content','initialize']:
    db.executescript((root/'infra/sqitch/revert'/f'{name}.sql').read_text())
assert not db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").fetchall()
print('PASS: normalized keys, types, referential integrity, cascades, and migration reversal')

# Upgrading an existing newsletter preserves its selection and authored body.
upgrade=sqlite3.connect(':memory:')
upgrade.execute('PRAGMA foreign_keys=ON')
for name in ['initialize','admin_content']:
    upgrade.executescript((root/'infra/sqitch/deploy'/f'{name}.sql').read_text())
upgrade.execute("INSERT INTO events(id,title,created_at,updated_at) VALUES('old-event','Existing event','then','then')")
upgrade.execute("INSERT INTO newsletters VALUES('old-news','Existing draft','Subject','Intro','Authored text','then','then')")
upgrade.execute("INSERT INTO newsletter_events VALUES('old-news','old-event',7)")
upgrade.commit()
upgrade.executescript((root/'infra/sqitch/deploy/programmes.sql').read_text())
assert upgrade.execute('SELECT i.newsletter_id,e.event_id,i.position FROM newsletter_items i JOIN newsletter_event_items e ON e.item_id=i.id').fetchall()==[('old-news','old-event',7)]
assert upgrade.execute("SELECT body FROM newsletters WHERE id='old-news'").fetchone()[0]=='Authored text'
upgrade.executescript((root/'infra/sqitch/revert/programmes.sql').read_text())
assert upgrade.execute('SELECT * FROM newsletter_events').fetchall()==[('old-news','old-event',7)]
print('PASS: existing newsletter links, order and authored text survive upgrade and reversal')

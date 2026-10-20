"""Persistent identity colors and reversible migration on a disposable SQLite database."""
from pathlib import Path
import sqlite3
root=Path(__file__).resolve().parents[2]
db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON')
for name in ['initialize','admin_content','programmes','identity_audit','media_metadata']:
 db.executescript((root/'infra/sqitch/deploy'/f'{name}.sql').read_text())
db.executescript("""INSERT INTO audit_actions VALUES('seed','bootstrap','account_setup','users','u','Editor','now');
INSERT INTO audit_context VALUES(1,'seed');
INSERT INTO actors VALUES('u','user','','now');
INSERT INTO users VALUES('u','user@gcf.org','Editor','hash','administrator',1,1,'now','now');
DELETE FROM audit_context;""")
db.executescript((root/'infra/sqitch/deploy/realtime_presence.sql').read_text())
assert len(db.execute("SELECT color FROM user_colors WHERE user_id='u'").fetchone()[0])==7
try:db.execute("UPDATE user_colors SET color='#abcdef'")
except sqlite3.IntegrityError:pass
else:raise AssertionError('Unattributed color change permitted')
db.execute("INSERT INTO audit_context VALUES(1,'seed')")
db.execute("UPDATE user_colors SET color='#abcdef'")
assert db.execute("SELECT COUNT(*) FROM audit_values WHERE column_name='color' AND new_value='#abcdef'").fetchone()[0]==1
try:db.execute("UPDATE user_colors SET color='not-a-color'")
except sqlite3.IntegrityError:pass
else:raise AssertionError('Invalid color permitted')
db.execute('DELETE FROM audit_context');db.commit()
db.executescript((root/'infra/sqitch/verify/realtime_presence.sql').read_text())
db.executescript((root/'infra/sqitch/revert/realtime_presence.sql').read_text())
assert db.execute('SELECT COUNT(*) FROM users').fetchone()[0]==1
assert db.execute('SELECT version FROM gcf_schema').fetchone()[0]==5
print('PASS: persistent account colors, audited writes, validation, and data-preserving reversal')

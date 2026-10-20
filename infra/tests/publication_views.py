"""Publication format migration, referential integrity and loss-preventing recovery."""
from pathlib import Path
import sqlite3
root=Path(__file__).resolve().parents[2]
db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON')
for name in ['initialize','admin_content','programmes','identity_audit','media_metadata','realtime_presence','rich_documents']:
 db.executescript((root/'infra/sqitch/deploy'/f'{name}.sql').read_text())
def context(action):
 db.execute("INSERT INTO audit_actions VALUES(?, 'legacy','test','newsletters','n','Test','2026-10-20T00:00:00Z')",[action])
 db.execute('INSERT INTO audit_context VALUES(1,?)',[action])
context('before')
db.execute("INSERT INTO newsletters VALUES('n','Existing','Subject','Opening','Closing','now','now')")
db.execute('DELETE FROM audit_context');db.commit()
migration=(root/'infra/sqitch/deploy/publication_views.sql').read_text()
db.executescript(migration)
assert db.execute('SELECT title FROM newsletters').fetchone()==('Existing',)
assert not db.execute('SELECT * FROM articles').fetchall()
context('article')
db.execute("INSERT INTO publications VALUES('a','Article','Headline','','','now','now','article')")
assert db.execute('SELECT id FROM articles').fetchall()==[('a',)]
assert db.execute('SELECT record_id FROM articles_attribution').fetchall()==[('a',)]
assert db.execute("SELECT new_value FROM audit_values WHERE column_name='format' AND new_value='article'").fetchone()
try:db.execute("UPDATE publications SET format='newsletter' WHERE id='a'")
except sqlite3.IntegrityError:pass
else:raise AssertionError('Publication format was mutable')
db.execute('DELETE FROM audit_context');db.commit()
revert=(root/'infra/sqitch/revert/publication_views.sql').read_text()
try:db.executescript(revert)
except sqlite3.IntegrityError:db.rollback()
else:raise AssertionError('Revert must not erase article meaning')
context('remove')
db.execute("DELETE FROM publications WHERE id='a'");db.execute('DELETE FROM audit_context');db.commit()
db.executescript(revert)
assert db.execute('SELECT title FROM newsletters').fetchone()==('Existing',)
assert db.execute('SELECT version FROM gcf_schema').fetchone()==(7,)
db.executescript(migration)
assert not db.execute('PRAGMA foreign_key_check').fetchall()
print('PASS: publication split preserves legacy data, ownership and audit; unsafe reversal is rejected; safe reversal/reapply succeeds')

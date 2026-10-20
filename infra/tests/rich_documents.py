from pathlib import Path
import sqlite3
root=Path(__file__).resolve().parents[2];db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON')
for name in ['initialize','admin_content','programmes','identity_audit','media_metadata','realtime_presence','rich_documents']:
 db.executescript((root/'infra/sqitch/deploy'/f'{name}.sql').read_text())
db.executescript("""INSERT INTO audit_actions VALUES('test','bootstrap','create','events','e','Story','now');
INSERT INTO audit_context VALUES(1,'test');
INSERT INTO events(id,title,summary,created_at,updated_at) VALUES('e','Story','Original prose','now','now');
INSERT INTO media(id,filename,mime_type,size_bytes,storage_key,thumbnail_key,created_at) VALUES('m','photo.jpg','image/jpeg',12,'m','t','now');
INSERT INTO event_inline_media VALUES('e','m');""")
try:db.execute("DELETE FROM media WHERE id='m'")
except sqlite3.IntegrityError:pass
else:raise AssertionError('Used inline image was deleted')
try:db.execute("INSERT INTO event_inline_media VALUES('e','missing')")
except sqlite3.IntegrityError:pass
else:raise AssertionError('Missing inline image accepted')
assert db.execute("SELECT COUNT(*) FROM audit_rows WHERE table_name='event_inline_media'").fetchone()[0]==1
db.execute("DELETE FROM events WHERE id='e'");assert db.execute('SELECT count(*) FROM event_inline_media').fetchone()[0]==0
db.execute('DELETE FROM audit_context');db.commit()
db.executescript((root/'infra/sqitch/verify/rich_documents.sql').read_text())
db.executescript((root/'infra/sqitch/revert/rich_documents.sql').read_text())
assert db.execute('SELECT version FROM gcf_schema').fetchone()[0]==6
assert db.execute("SELECT filename FROM media WHERE id='m'").fetchone()[0]=='photo.jpg'
print('PASS: inline image foreign keys, deletion protection, audit capture, cascade, migration reversal')

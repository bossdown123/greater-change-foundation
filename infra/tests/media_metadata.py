from pathlib import Path
import sqlite3
root=Path(__file__).resolve().parents[2]
db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON')
for name in ['initialize','admin_content','programmes','identity_audit','media_metadata']:
 db.executescript((root/'infra/sqitch/deploy'/f'{name}.sql').read_text())
db.execute("INSERT INTO audit_actions VALUES('metadata-test','bootstrap','upload','media','m','Photo','now')")
db.execute("INSERT INTO audit_context VALUES(1,'metadata-test')")
db.execute("INSERT INTO media(id,filename,mime_type,size_bytes,storage_key,thumbnail_key,created_at) VALUES('m','photo.jpg','image/jpeg',10,'original','thumbnail','now')")
db.execute("INSERT INTO media_dimensions VALUES('m',6000,4000)")
db.execute("INSERT INTO media_captures VALUES('m','2024-02-29T12:00:00',NULL,'original')")
db.execute("INSERT INTO media_coordinates VALUES('m',18.1,-76.5,NULL)")
db.execute("INSERT INTO media_place_names VALUES('m','city','Kingston')")
for sql in ["INSERT INTO media_dimensions VALUES('m',6000,4000)","UPDATE media_dimensions SET width=0", "UPDATE media_coordinates SET latitude=91", "INSERT INTO media_place_names VALUES('m','made-up','Somewhere')"]:
 try:db.execute(sql)
 except sqlite3.IntegrityError:pass
 else:raise AssertionError(sql)
db.execute('DELETE FROM audit_context');db.commit()
assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
assert db.execute("SELECT count(*) FROM audit_rows WHERE table_name='media_captures'").fetchone()[0]==1
db.executescript((root/'infra/sqitch/revert/media_metadata.sql').read_text())
assert db.execute('SELECT filename FROM media').fetchone()[0]=='photo.jpg'
print('PASS: normalized capture facts, optional time zone, bounded coordinates, audit coverage, and metadata migration reversal')

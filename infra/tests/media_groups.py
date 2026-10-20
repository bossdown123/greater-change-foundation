"""Image collections: normalized membership, typed reuse, audit and lossless recovery."""
from pathlib import Path
import sqlite3
root=Path(__file__).resolve().parents[2]
db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON')
for name in ['initialize','admin_content','programmes','identity_audit','media_metadata','realtime_presence','rich_documents','publication_views','media_groups']:
 db.executescript((root/'infra/sqitch/deploy'/f'{name}.sql').read_text())
def action(n):
 db.execute("INSERT INTO audit_actions VALUES(?, 'legacy','test','media_groups',NULL,'','2026-10-20T00:00:00Z')",[n]);db.execute('INSERT INTO audit_context VALUES(1,?)',[n])
def denied(sql,args=()):
 try:db.execute(sql,args)
 except sqlite3.IntegrityError:return
 raise AssertionError('Expected constraint failure: '+sql)
g='a'*32;h='b'*32;m='c'*32;e='d'*32;p='e'*32
# All writes need an authenticated transaction context.
denied('INSERT INTO media_groups VALUES(?,?,?,?)',(g,'Group','now','now'))
action('create')
db.execute('INSERT INTO media_groups VALUES(?,?,?,?)',(g,'Photos','now','now'))
db.execute('INSERT INTO media_groups VALUES(?,?,?,?)',(h,'Other photos','now','now'))
db.execute("INSERT INTO media(id,filename,mime_type,size_bytes,storage_key,thumbnail_key,alt,caption,created_at) VALUES(?,'x.jpg','image/jpeg',1,'original','thumb','','','now')",[m])
db.execute("INSERT INTO events VALUES(?,'Activity','',NULL,NULL,'USD','now','now')",[e])
db.execute("INSERT INTO publications VALUES(?,'Article','Headline','','','now','now','article')",[p])
db.execute('INSERT INTO media_group_members VALUES(?,?,0)',[g,m]);db.execute('INSERT INTO media_group_members VALUES(?,?,0)',[h,m])
db.execute('INSERT INTO event_media_groups VALUES(?,?,0)',[e,g]);db.execute('INSERT INTO publication_media_groups VALUES(?,?,0)',[p,g])
assert db.execute('SELECT count(*) FROM media').fetchone()==(1,),'reusing a photo must not copy its data'
assert db.execute('SELECT created_by FROM media_groups_attribution WHERE record_id=?',[g]).fetchone()==('legacy',)
assert db.execute("SELECT count(*) FROM audit_rows WHERE table_name='media_group_members'").fetchone()==(2,)
denied('INSERT INTO media_group_members VALUES(?,?,1)',[g,m])
denied('INSERT INTO event_media_groups VALUES(?,?,1)',[p,g])
denied('DELETE FROM media WHERE id=?',[m]);denied('DELETE FROM media_groups WHERE id=?',[g])
denied('UPDATE media_group_members SET group_id=? WHERE group_id=?',[h,g])
db.execute('DELETE FROM audit_context');db.commit()
try:db.executescript((root/'infra/sqitch/revert/media_groups.sql').read_text())
except sqlite3.IntegrityError:db.rollback()
else:raise AssertionError('Nonempty collections must prevent a lossy revert')
action('cleanup');db.execute('DELETE FROM event_media_groups');db.execute('DELETE FROM publication_media_groups');db.execute('DELETE FROM media_groups');db.execute('DELETE FROM audit_context');db.commit()
assert not db.execute('PRAGMA foreign_key_check').fetchall()
db.executescript((root/'infra/sqitch/revert/media_groups.sql').read_text());assert db.execute('SELECT version FROM gcf_schema').fetchone()==(8,)
db.executescript((root/'infra/sqitch/deploy/media_groups.sql').read_text())
print('PASS: reusable collection membership, typed content links, uniqueness, retained photos, actor audit and guarded recovery')

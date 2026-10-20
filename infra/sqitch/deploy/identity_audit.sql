BEGIN;
CREATE TABLE actors (
 id TEXT PRIMARY KEY,
 kind TEXT NOT NULL CHECK(kind IN ('user','system')),
 label TEXT NOT NULL CHECK((kind='user' AND label='') OR (kind='system' AND length(label)>0)),
 created_at TEXT NOT NULL
) STRICT;
INSERT INTO actors VALUES('legacy','system','Legacy import',strftime('%Y-%m-%dT%H:%M:%fZ','now'));
INSERT INTO actors VALUES('bootstrap','system','Account setup',strftime('%Y-%m-%dT%H:%M:%fZ','now'));
CREATE TABLE users (
 id TEXT PRIMARY KEY REFERENCES actors(id) ON DELETE RESTRICT,
 email TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(email=lower(trim(email)) AND instr(email,'@')>1),
 name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 120),
 password_hash TEXT NOT NULL,
 role TEXT NOT NULL CHECK(role IN ('administrator','editor')),
 active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)),
 session_version INTEGER NOT NULL DEFAULT 1 CHECK(session_version>0),
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL
) STRICT;
CREATE TRIGGER user_actor_kind BEFORE INSERT ON users WHEN NOT EXISTS(SELECT 1 FROM actors WHERE id=NEW.id AND kind='user')
BEGIN SELECT RAISE(ABORT,'A user requires a user actor'); END;
CREATE TRIGGER last_administrator BEFORE UPDATE OF role,active ON users
WHEN OLD.role='administrator' AND OLD.active=1 AND (NEW.role<>'administrator' OR NEW.active=0)
AND NOT EXISTS(SELECT 1 FROM users WHERE id<>OLD.id AND role='administrator' AND active=1)
BEGIN SELECT RAISE(ABORT,'Keep at least one active administrator'); END;
CREATE TRIGGER retain_user_identity BEFORE DELETE ON users
BEGIN SELECT RAISE(ABORT,'Disable accounts instead of deleting their identity'); END;
CREATE TRIGGER retain_actor_identity BEFORE DELETE ON actors
BEGIN SELECT RAISE(ABORT,'Actor identities are permanent'); END;
CREATE TABLE audit_actions (
 id TEXT PRIMARY KEY,
 actor_id TEXT NOT NULL REFERENCES actors(id) ON DELETE RESTRICT,
 operation TEXT NOT NULL,
 resource_type TEXT NOT NULL,
 resource_id TEXT,
 resource_title TEXT NOT NULL DEFAULT '',
 occurred_at TEXT NOT NULL
) STRICT;
CREATE INDEX audit_actions_time ON audit_actions(occurred_at DESC,id);
CREATE INDEX audit_actions_actor ON audit_actions(actor_id,occurred_at DESC);
CREATE INDEX audit_actions_resource ON audit_actions(resource_type,resource_id,occurred_at DESC);
CREATE TABLE audit_rows (
 id INTEGER PRIMARY KEY,
 action_id TEXT NOT NULL REFERENCES audit_actions(id) ON DELETE RESTRICT,
 table_name TEXT NOT NULL,
 operation TEXT NOT NULL CHECK(operation IN ('insert','update','delete'))
) STRICT;
CREATE INDEX audit_rows_action ON audit_rows(action_id,id);
CREATE TABLE audit_values (
 row_id INTEGER NOT NULL REFERENCES audit_rows(id) ON DELETE RESTRICT,
 column_name TEXT NOT NULL,
 old_type TEXT NOT NULL CHECK(old_type IN ('null','text','integer','real','blob')),
 old_value TEXT,
 new_type TEXT NOT NULL CHECK(new_type IN ('null','text','integer','real','blob')),
 new_value TEXT,
 PRIMARY KEY(row_id,column_name),
 CHECK((old_type='null')=(old_value IS NULL)),
 CHECK((new_type='null')=(new_value IS NULL))
) STRICT;
CREATE TABLE audit_context (
 singleton INTEGER PRIMARY KEY CHECK(singleton=1),
 action_id TEXT NOT NULL REFERENCES audit_actions(id)
) STRICT;
CREATE TABLE events_attribution (record_id TEXT PRIMARY KEY REFERENCES events(id) ON DELETE CASCADE,created_by TEXT NOT NULL REFERENCES actors(id),updated_by TEXT NOT NULL REFERENCES actors(id)) STRICT;
INSERT INTO events_attribution SELECT id,'legacy','legacy' FROM events;
CREATE TABLE initiatives_attribution (record_id TEXT PRIMARY KEY REFERENCES initiatives(id) ON DELETE CASCADE,created_by TEXT NOT NULL REFERENCES actors(id),updated_by TEXT NOT NULL REFERENCES actors(id)) STRICT;
INSERT INTO initiatives_attribution SELECT id,'legacy','legacy' FROM initiatives;
CREATE TABLE campaigns_attribution (record_id TEXT PRIMARY KEY REFERENCES campaigns(id) ON DELETE CASCADE,created_by TEXT NOT NULL REFERENCES actors(id),updated_by TEXT NOT NULL REFERENCES actors(id)) STRICT;
INSERT INTO campaigns_attribution SELECT id,'legacy','legacy' FROM campaigns;
CREATE TABLE newsletters_attribution (record_id TEXT PRIMARY KEY REFERENCES newsletters(id) ON DELETE CASCADE,created_by TEXT NOT NULL REFERENCES actors(id),updated_by TEXT NOT NULL REFERENCES actors(id)) STRICT;
INSERT INTO newsletters_attribution SELECT id,'legacy','legacy' FROM newsletters;
CREATE TABLE media_attribution (record_id TEXT PRIMARY KEY REFERENCES media(id) ON DELETE CASCADE,created_by TEXT NOT NULL REFERENCES actors(id),updated_by TEXT NOT NULL REFERENCES actors(id)) STRICT;
INSERT INTO media_attribution SELECT id,'legacy','legacy' FROM media;
ALTER TABLE media ADD COLUMN updated_at TEXT NOT NULL DEFAULT '';
UPDATE media SET updated_at=created_at;
CREATE TRIGGER audit_guard_actors_insert BEFORE INSERT ON actors
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_actors_insert AFTER INSERT ON actors
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'actors','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'label',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.label),CAST(NEW.label AS TEXT);
END;
CREATE TRIGGER audit_guard_actors_update BEFORE UPDATE ON actors
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_actors_update AFTER UPDATE ON actors WHEN OLD.id IS NOT NEW.id OR OLD.kind IS NOT NEW.kind OR OLD.label IS NOT NEW.label
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'actors','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT) WHERE OLD.kind IS NOT NEW.kind;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'label',typeof(OLD.label),CAST(OLD.label AS TEXT),typeof(NEW.label),CAST(NEW.label AS TEXT) WHERE OLD.label IS NOT NEW.label;
END;
CREATE TRIGGER audit_guard_actors_delete BEFORE DELETE ON actors
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_actors_delete AFTER DELETE ON actors
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'actors','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'label',typeof(OLD.label),CAST(OLD.label AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_users_insert BEFORE INSERT ON users
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_users_insert AFTER INSERT ON users
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'users','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'email',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.email),CAST(NEW.email AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'name',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.name),CAST(NEW.name AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'role',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.role),CAST(NEW.role AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'active',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.active),CAST(NEW.active AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'password_changed','null',NULL,'text','yes';
END;
CREATE TRIGGER audit_guard_users_update BEFORE UPDATE ON users
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_users_update AFTER UPDATE ON users WHEN OLD.id IS NOT NEW.id OR OLD.email IS NOT NEW.email OR OLD.name IS NOT NEW.name OR OLD.role IS NOT NEW.role OR OLD.active IS NOT NEW.active OR OLD.password_hash IS NOT NEW.password_hash
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'users','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'email',typeof(OLD.email),CAST(OLD.email AS TEXT),typeof(NEW.email),CAST(NEW.email AS TEXT) WHERE OLD.email IS NOT NEW.email;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'name',typeof(OLD.name),CAST(OLD.name AS TEXT),typeof(NEW.name),CAST(NEW.name AS TEXT) WHERE OLD.name IS NOT NEW.name;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'role',typeof(OLD.role),CAST(OLD.role AS TEXT),typeof(NEW.role),CAST(NEW.role AS TEXT) WHERE OLD.role IS NOT NEW.role;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'active',typeof(OLD.active),CAST(OLD.active AS TEXT),typeof(NEW.active),CAST(NEW.active AS TEXT) WHERE OLD.active IS NOT NEW.active;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'password_changed','null',NULL,'text','yes' WHERE OLD.password_hash IS NOT NEW.password_hash;
END;
CREATE TRIGGER audit_guard_users_delete BEFORE DELETE ON users
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_users_delete AFTER DELETE ON users
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'users','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'email',typeof(OLD.email),CAST(OLD.email AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'name',typeof(OLD.name),CAST(OLD.name AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'role',typeof(OLD.role),CAST(OLD.role AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'active',typeof(OLD.active),CAST(OLD.active AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_events_insert BEFORE INSERT ON events
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_events_insert AFTER INSERT ON events
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'events','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'summary',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.summary),CAST(NEW.summary AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'participant_count',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.participant_count),CAST(NEW.participant_count AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'funds_minor',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.funds_minor),CAST(NEW.funds_minor AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'currency',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.currency),CAST(NEW.currency AS TEXT);
 INSERT INTO events_attribution VALUES(NEW.id,(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)),(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)));
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_events_update BEFORE UPDATE ON events
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_events_update AFTER UPDATE ON events WHEN OLD.id IS NOT NEW.id OR OLD.title IS NOT NEW.title OR OLD.summary IS NOT NEW.summary OR OLD.participant_count IS NOT NEW.participant_count OR OLD.funds_minor IS NOT NEW.funds_minor OR OLD.currency IS NOT NEW.currency
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'events','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT) WHERE OLD.title IS NOT NEW.title;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'summary',typeof(OLD.summary),CAST(OLD.summary AS TEXT),typeof(NEW.summary),CAST(NEW.summary AS TEXT) WHERE OLD.summary IS NOT NEW.summary;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'participant_count',typeof(OLD.participant_count),CAST(OLD.participant_count AS TEXT),typeof(NEW.participant_count),CAST(NEW.participant_count AS TEXT) WHERE OLD.participant_count IS NOT NEW.participant_count;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'funds_minor',typeof(OLD.funds_minor),CAST(OLD.funds_minor AS TEXT),typeof(NEW.funds_minor),CAST(NEW.funds_minor AS TEXT) WHERE OLD.funds_minor IS NOT NEW.funds_minor;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'currency',typeof(OLD.currency),CAST(OLD.currency AS TEXT),typeof(NEW.currency),CAST(NEW.currency AS TEXT) WHERE OLD.currency IS NOT NEW.currency;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_events_delete BEFORE DELETE ON events
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_events_delete AFTER DELETE ON events
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'events','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'summary',typeof(OLD.summary),CAST(OLD.summary AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'participant_count',typeof(OLD.participant_count),CAST(OLD.participant_count AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'funds_minor',typeof(OLD.funds_minor),CAST(OLD.funds_minor AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'currency',typeof(OLD.currency),CAST(OLD.currency AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_event_dates_insert BEFORE INSERT ON event_dates
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_dates_insert AFTER INSERT ON event_dates
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_dates','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_date',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_date),CAST(NEW.event_date AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_dates_update BEFORE UPDATE ON event_dates
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_dates_update AFTER UPDATE ON event_dates WHEN OLD.event_id IS NOT NEW.event_id OR OLD.position IS NOT NEW.position OR OLD.event_date IS NOT NEW.event_date
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_dates','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT) WHERE OLD.event_id IS NOT NEW.event_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_date',typeof(OLD.event_date),CAST(OLD.event_date AS TEXT),typeof(NEW.event_date),CAST(NEW.event_date AS TEXT) WHERE OLD.event_date IS NOT NEW.event_date;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_dates_delete BEFORE DELETE ON event_dates
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_dates_delete AFTER DELETE ON event_dates
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_dates','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_date',typeof(OLD.event_date),CAST(OLD.event_date AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.event_id;
END;
CREATE TRIGGER audit_guard_locations_insert BEFORE INSERT ON locations
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_locations_insert AFTER INSERT ON locations
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'locations','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'name',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.name),CAST(NEW.name AS TEXT);
END;
CREATE TRIGGER audit_guard_locations_update BEFORE UPDATE ON locations
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_locations_update AFTER UPDATE ON locations WHEN OLD.id IS NOT NEW.id OR OLD.name IS NOT NEW.name
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'locations','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'name',typeof(OLD.name),CAST(OLD.name AS TEXT),typeof(NEW.name),CAST(NEW.name AS TEXT) WHERE OLD.name IS NOT NEW.name;
END;
CREATE TRIGGER audit_guard_locations_delete BEFORE DELETE ON locations
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_locations_delete AFTER DELETE ON locations
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'locations','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'name',typeof(OLD.name),CAST(OLD.name AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_event_locations_insert BEFORE INSERT ON event_locations
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_locations_insert AFTER INSERT ON event_locations
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_locations','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'location_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.location_id),CAST(NEW.location_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_locations_update BEFORE UPDATE ON event_locations
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_locations_update AFTER UPDATE ON event_locations WHEN OLD.event_id IS NOT NEW.event_id OR OLD.location_id IS NOT NEW.location_id OR OLD.position IS NOT NEW.position
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_locations','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT) WHERE OLD.event_id IS NOT NEW.event_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'location_id',typeof(OLD.location_id),CAST(OLD.location_id AS TEXT),typeof(NEW.location_id),CAST(NEW.location_id AS TEXT) WHERE OLD.location_id IS NOT NEW.location_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_locations_delete BEFORE DELETE ON event_locations
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_locations_delete AFTER DELETE ON event_locations
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_locations','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'location_id',typeof(OLD.location_id),CAST(OLD.location_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.event_id;
END;
CREATE TRIGGER audit_guard_field_definitions_insert BEFORE INSERT ON field_definitions
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_field_definitions_insert AFTER INSERT ON field_definitions
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'field_definitions','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'label',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.label),CAST(NEW.label AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT);
END;
CREATE TRIGGER audit_guard_field_definitions_update BEFORE UPDATE ON field_definitions
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_field_definitions_update AFTER UPDATE ON field_definitions WHEN OLD.id IS NOT NEW.id OR OLD.label IS NOT NEW.label OR OLD.kind IS NOT NEW.kind
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'field_definitions','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'label',typeof(OLD.label),CAST(OLD.label AS TEXT),typeof(NEW.label),CAST(NEW.label AS TEXT) WHERE OLD.label IS NOT NEW.label;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT) WHERE OLD.kind IS NOT NEW.kind;
END;
CREATE TRIGGER audit_guard_field_definitions_delete BEFORE DELETE ON field_definitions
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_field_definitions_delete AFTER DELETE ON field_definitions
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'field_definitions','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'label',typeof(OLD.label),CAST(OLD.label AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_event_field_values_insert BEFORE INSERT ON event_field_values
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_field_values_insert AFTER INSERT ON event_field_values
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_field_values','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'field_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.field_id),CAST(NEW.field_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'text_value',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.text_value),CAST(NEW.text_value AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'number_value',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.number_value),CAST(NEW.number_value AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'date_value',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.date_value),CAST(NEW.date_value AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'link_value',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.link_value),CAST(NEW.link_value AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_field_values_update BEFORE UPDATE ON event_field_values
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_field_values_update AFTER UPDATE ON event_field_values WHEN OLD.event_id IS NOT NEW.event_id OR OLD.field_id IS NOT NEW.field_id OR OLD.position IS NOT NEW.position OR OLD.text_value IS NOT NEW.text_value OR OLD.number_value IS NOT NEW.number_value OR OLD.date_value IS NOT NEW.date_value OR OLD.link_value IS NOT NEW.link_value
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_field_values','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT) WHERE OLD.event_id IS NOT NEW.event_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'field_id',typeof(OLD.field_id),CAST(OLD.field_id AS TEXT),typeof(NEW.field_id),CAST(NEW.field_id AS TEXT) WHERE OLD.field_id IS NOT NEW.field_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'text_value',typeof(OLD.text_value),CAST(OLD.text_value AS TEXT),typeof(NEW.text_value),CAST(NEW.text_value AS TEXT) WHERE OLD.text_value IS NOT NEW.text_value;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'number_value',typeof(OLD.number_value),CAST(OLD.number_value AS TEXT),typeof(NEW.number_value),CAST(NEW.number_value AS TEXT) WHERE OLD.number_value IS NOT NEW.number_value;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'date_value',typeof(OLD.date_value),CAST(OLD.date_value AS TEXT),typeof(NEW.date_value),CAST(NEW.date_value AS TEXT) WHERE OLD.date_value IS NOT NEW.date_value;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'link_value',typeof(OLD.link_value),CAST(OLD.link_value AS TEXT),typeof(NEW.link_value),CAST(NEW.link_value AS TEXT) WHERE OLD.link_value IS NOT NEW.link_value;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_event_field_values_delete BEFORE DELETE ON event_field_values
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_field_values_delete AFTER DELETE ON event_field_values
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_field_values','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'field_id',typeof(OLD.field_id),CAST(OLD.field_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'text_value',typeof(OLD.text_value),CAST(OLD.text_value AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'number_value',typeof(OLD.number_value),CAST(OLD.number_value AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'date_value',typeof(OLD.date_value),CAST(OLD.date_value AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'link_value',typeof(OLD.link_value),CAST(OLD.link_value AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.event_id;
END;
CREATE TRIGGER audit_guard_media_insert BEFORE INSERT ON media
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_insert AFTER INSERT ON media
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'filename',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.filename),CAST(NEW.filename AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'mime_type',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.mime_type),CAST(NEW.mime_type AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'size_bytes',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.size_bytes),CAST(NEW.size_bytes AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'storage_key',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.storage_key),CAST(NEW.storage_key AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'thumbnail_key',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.thumbnail_key),CAST(NEW.thumbnail_key AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'alt',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.alt),CAST(NEW.alt AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'caption',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.caption),CAST(NEW.caption AS TEXT);
 INSERT INTO media_attribution VALUES(NEW.id,(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)),(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)));
 UPDATE media SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_media_update BEFORE UPDATE ON media
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_update AFTER UPDATE ON media WHEN OLD.id IS NOT NEW.id OR OLD.filename IS NOT NEW.filename OR OLD.mime_type IS NOT NEW.mime_type OR OLD.size_bytes IS NOT NEW.size_bytes OR OLD.storage_key IS NOT NEW.storage_key OR OLD.thumbnail_key IS NOT NEW.thumbnail_key OR OLD.alt IS NOT NEW.alt OR OLD.caption IS NOT NEW.caption
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'filename',typeof(OLD.filename),CAST(OLD.filename AS TEXT),typeof(NEW.filename),CAST(NEW.filename AS TEXT) WHERE OLD.filename IS NOT NEW.filename;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'mime_type',typeof(OLD.mime_type),CAST(OLD.mime_type AS TEXT),typeof(NEW.mime_type),CAST(NEW.mime_type AS TEXT) WHERE OLD.mime_type IS NOT NEW.mime_type;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'size_bytes',typeof(OLD.size_bytes),CAST(OLD.size_bytes AS TEXT),typeof(NEW.size_bytes),CAST(NEW.size_bytes AS TEXT) WHERE OLD.size_bytes IS NOT NEW.size_bytes;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'storage_key',typeof(OLD.storage_key),CAST(OLD.storage_key AS TEXT),typeof(NEW.storage_key),CAST(NEW.storage_key AS TEXT) WHERE OLD.storage_key IS NOT NEW.storage_key;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'thumbnail_key',typeof(OLD.thumbnail_key),CAST(OLD.thumbnail_key AS TEXT),typeof(NEW.thumbnail_key),CAST(NEW.thumbnail_key AS TEXT) WHERE OLD.thumbnail_key IS NOT NEW.thumbnail_key;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'alt',typeof(OLD.alt),CAST(OLD.alt AS TEXT),typeof(NEW.alt),CAST(NEW.alt AS TEXT) WHERE OLD.alt IS NOT NEW.alt;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'caption',typeof(OLD.caption),CAST(OLD.caption AS TEXT),typeof(NEW.caption),CAST(NEW.caption AS TEXT) WHERE OLD.caption IS NOT NEW.caption;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.id;
 UPDATE media SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_media_delete BEFORE DELETE ON media
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_delete AFTER DELETE ON media
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'filename',typeof(OLD.filename),CAST(OLD.filename AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'mime_type',typeof(OLD.mime_type),CAST(OLD.mime_type AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'size_bytes',typeof(OLD.size_bytes),CAST(OLD.size_bytes AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'storage_key',typeof(OLD.storage_key),CAST(OLD.storage_key AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'thumbnail_key',typeof(OLD.thumbnail_key),CAST(OLD.thumbnail_key AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'alt',typeof(OLD.alt),CAST(OLD.alt AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'caption',typeof(OLD.caption),CAST(OLD.caption AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_event_media_insert BEFORE INSERT ON event_media
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_media_insert AFTER INSERT ON event_media
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_media','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
 UPDATE media SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_event_media_update BEFORE UPDATE ON event_media
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_media_update AFTER UPDATE ON event_media WHEN OLD.event_id IS NOT NEW.event_id OR OLD.media_id IS NOT NEW.media_id OR OLD.position IS NOT NEW.position
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_media','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT) WHERE OLD.event_id IS NOT NEW.event_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
 UPDATE media SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_event_media_delete BEFORE DELETE ON event_media
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_event_media_delete AFTER DELETE ON event_media
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'event_media','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.event_id;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.media_id;
 UPDATE media SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.media_id;
END;
CREATE TRIGGER audit_guard_newsletters_insert BEFORE INSERT ON newsletters
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletters_insert AFTER INSERT ON newsletters
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletters','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'subject',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.subject),CAST(NEW.subject AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'introduction',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.introduction),CAST(NEW.introduction AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'body',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.body),CAST(NEW.body AS TEXT);
 INSERT INTO newsletters_attribution VALUES(NEW.id,(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)),(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)));
 UPDATE newsletters SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_newsletters_update BEFORE UPDATE ON newsletters
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletters_update AFTER UPDATE ON newsletters WHEN OLD.id IS NOT NEW.id OR OLD.title IS NOT NEW.title OR OLD.subject IS NOT NEW.subject OR OLD.introduction IS NOT NEW.introduction OR OLD.body IS NOT NEW.body
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletters','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT) WHERE OLD.title IS NOT NEW.title;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'subject',typeof(OLD.subject),CAST(OLD.subject AS TEXT),typeof(NEW.subject),CAST(NEW.subject AS TEXT) WHERE OLD.subject IS NOT NEW.subject;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'introduction',typeof(OLD.introduction),CAST(OLD.introduction AS TEXT),typeof(NEW.introduction),CAST(NEW.introduction AS TEXT) WHERE OLD.introduction IS NOT NEW.introduction;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'body',typeof(OLD.body),CAST(OLD.body AS TEXT),typeof(NEW.body),CAST(NEW.body AS TEXT) WHERE OLD.body IS NOT NEW.body;
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.id;
 UPDATE newsletters SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_newsletters_delete BEFORE DELETE ON newsletters
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletters_delete AFTER DELETE ON newsletters
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletters','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'subject',typeof(OLD.subject),CAST(OLD.subject AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'introduction',typeof(OLD.introduction),CAST(OLD.introduction AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'body',typeof(OLD.body),CAST(OLD.body AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_initiatives_insert BEFORE INSERT ON initiatives
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiatives_insert AFTER INSERT ON initiatives
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiatives','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'summary',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.summary),CAST(NEW.summary AS TEXT);
 INSERT INTO initiatives_attribution VALUES(NEW.id,(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)),(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)));
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_initiatives_update BEFORE UPDATE ON initiatives
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiatives_update AFTER UPDATE ON initiatives WHEN OLD.id IS NOT NEW.id OR OLD.title IS NOT NEW.title OR OLD.summary IS NOT NEW.summary
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiatives','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT) WHERE OLD.title IS NOT NEW.title;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'summary',typeof(OLD.summary),CAST(OLD.summary AS TEXT),typeof(NEW.summary),CAST(NEW.summary AS TEXT) WHERE OLD.summary IS NOT NEW.summary;
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_initiatives_delete BEFORE DELETE ON initiatives
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiatives_delete AFTER DELETE ON initiatives
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiatives','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'summary',typeof(OLD.summary),CAST(OLD.summary AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_campaigns_insert BEFORE INSERT ON campaigns
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaigns_insert AFTER INSERT ON campaigns
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaigns','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'summary',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.summary),CAST(NEW.summary AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'target_minor',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.target_minor),CAST(NEW.target_minor AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'raised_minor',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.raised_minor),CAST(NEW.raised_minor AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'currency',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.currency),CAST(NEW.currency AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'starts_on',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.starts_on),CAST(NEW.starts_on AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'ends_on',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.ends_on),CAST(NEW.ends_on AS TEXT);
 INSERT INTO campaigns_attribution VALUES(NEW.id,(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)),(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)));
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_campaigns_update BEFORE UPDATE ON campaigns
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaigns_update AFTER UPDATE ON campaigns WHEN OLD.id IS NOT NEW.id OR OLD.title IS NOT NEW.title OR OLD.summary IS NOT NEW.summary OR OLD.target_minor IS NOT NEW.target_minor OR OLD.raised_minor IS NOT NEW.raised_minor OR OLD.currency IS NOT NEW.currency OR OLD.starts_on IS NOT NEW.starts_on OR OLD.ends_on IS NOT NEW.ends_on
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaigns','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT) WHERE OLD.title IS NOT NEW.title;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'summary',typeof(OLD.summary),CAST(OLD.summary AS TEXT),typeof(NEW.summary),CAST(NEW.summary AS TEXT) WHERE OLD.summary IS NOT NEW.summary;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'target_minor',typeof(OLD.target_minor),CAST(OLD.target_minor AS TEXT),typeof(NEW.target_minor),CAST(NEW.target_minor AS TEXT) WHERE OLD.target_minor IS NOT NEW.target_minor;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'raised_minor',typeof(OLD.raised_minor),CAST(OLD.raised_minor AS TEXT),typeof(NEW.raised_minor),CAST(NEW.raised_minor AS TEXT) WHERE OLD.raised_minor IS NOT NEW.raised_minor;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'currency',typeof(OLD.currency),CAST(OLD.currency AS TEXT),typeof(NEW.currency),CAST(NEW.currency AS TEXT) WHERE OLD.currency IS NOT NEW.currency;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'starts_on',typeof(OLD.starts_on),CAST(OLD.starts_on AS TEXT),typeof(NEW.starts_on),CAST(NEW.starts_on AS TEXT) WHERE OLD.starts_on IS NOT NEW.starts_on;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'ends_on',typeof(OLD.ends_on),CAST(OLD.ends_on AS TEXT),typeof(NEW.ends_on),CAST(NEW.ends_on AS TEXT) WHERE OLD.ends_on IS NOT NEW.ends_on;
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
CREATE TRIGGER audit_guard_campaigns_delete BEFORE DELETE ON campaigns
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaigns_delete AFTER DELETE ON campaigns
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaigns','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'summary',typeof(OLD.summary),CAST(OLD.summary AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'target_minor',typeof(OLD.target_minor),CAST(OLD.target_minor AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'raised_minor',typeof(OLD.raised_minor),CAST(OLD.raised_minor AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'currency',typeof(OLD.currency),CAST(OLD.currency AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'starts_on',typeof(OLD.starts_on),CAST(OLD.starts_on AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'ends_on',typeof(OLD.ends_on),CAST(OLD.ends_on AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_initiative_events_insert BEFORE INSERT ON initiative_events
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiative_events_insert AFTER INSERT ON initiative_events
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiative_events','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.initiative_id;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_initiative_events_update BEFORE UPDATE ON initiative_events
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiative_events_update AFTER UPDATE ON initiative_events WHEN OLD.initiative_id IS NOT NEW.initiative_id OR OLD.event_id IS NOT NEW.event_id OR OLD.position IS NOT NEW.position
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiative_events','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT) WHERE OLD.initiative_id IS NOT NEW.initiative_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT) WHERE OLD.event_id IS NOT NEW.event_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.initiative_id;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_initiative_events_delete BEFORE DELETE ON initiative_events
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_initiative_events_delete AFTER DELETE ON initiative_events
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'initiative_events','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.initiative_id;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.event_id;
END;
CREATE TRIGGER audit_guard_campaign_events_insert BEFORE INSERT ON campaign_events
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_events_insert AFTER INSERT ON campaign_events
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_events','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.campaign_id;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_campaign_events_update BEFORE UPDATE ON campaign_events
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_events_update AFTER UPDATE ON campaign_events WHEN OLD.campaign_id IS NOT NEW.campaign_id OR OLD.event_id IS NOT NEW.event_id OR OLD.position IS NOT NEW.position
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_events','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT) WHERE OLD.campaign_id IS NOT NEW.campaign_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT) WHERE OLD.event_id IS NOT NEW.event_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.campaign_id;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.event_id;
END;
CREATE TRIGGER audit_guard_campaign_events_delete BEFORE DELETE ON campaign_events
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_events_delete AFTER DELETE ON campaign_events
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_events','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.campaign_id;
 UPDATE events_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.event_id;
 UPDATE events SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.event_id;
END;
CREATE TRIGGER audit_guard_campaign_initiatives_insert BEFORE INSERT ON campaign_initiatives
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_initiatives_insert AFTER INSERT ON campaign_initiatives
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_initiatives','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.campaign_id;
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.initiative_id;
END;
CREATE TRIGGER audit_guard_campaign_initiatives_update BEFORE UPDATE ON campaign_initiatives
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_initiatives_update AFTER UPDATE ON campaign_initiatives WHEN OLD.campaign_id IS NOT NEW.campaign_id OR OLD.initiative_id IS NOT NEW.initiative_id OR OLD.position IS NOT NEW.position
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_initiatives','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT) WHERE OLD.campaign_id IS NOT NEW.campaign_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT) WHERE OLD.initiative_id IS NOT NEW.initiative_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.campaign_id;
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.initiative_id;
END;
CREATE TRIGGER audit_guard_campaign_initiatives_delete BEFORE DELETE ON campaign_initiatives
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_campaign_initiatives_delete AFTER DELETE ON campaign_initiatives
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'campaign_initiatives','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE campaigns_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.campaign_id;
 UPDATE campaigns SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.campaign_id;
 UPDATE initiatives_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.initiative_id;
 UPDATE initiatives SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.initiative_id;
END;
CREATE TRIGGER audit_guard_newsletter_items_insert BEFORE INSERT ON newsletter_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_items_insert AFTER INSERT ON newsletter_items
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_items','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'newsletter_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.newsletter_id),CAST(NEW.newsletter_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT);
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.newsletter_id;
 UPDATE newsletters SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.newsletter_id;
END;
CREATE TRIGGER audit_guard_newsletter_items_update BEFORE UPDATE ON newsletter_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_items_update AFTER UPDATE ON newsletter_items WHEN OLD.id IS NOT NEW.id OR OLD.newsletter_id IS NOT NEW.newsletter_id OR OLD.position IS NOT NEW.position OR OLD.kind IS NOT NEW.kind
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_items','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'newsletter_id',typeof(OLD.newsletter_id),CAST(OLD.newsletter_id AS TEXT),typeof(NEW.newsletter_id),CAST(NEW.newsletter_id AS TEXT) WHERE OLD.newsletter_id IS NOT NEW.newsletter_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NEW.position),CAST(NEW.position AS TEXT) WHERE OLD.position IS NOT NEW.position;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT) WHERE OLD.kind IS NOT NEW.kind;
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.newsletter_id;
 UPDATE newsletters SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.newsletter_id;
END;
CREATE TRIGGER audit_guard_newsletter_items_delete BEFORE DELETE ON newsletter_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_items_delete AFTER DELETE ON newsletter_items
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_items','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'newsletter_id',typeof(OLD.newsletter_id),CAST(OLD.newsletter_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'position',typeof(OLD.position),CAST(OLD.position AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.newsletter_id;
 UPDATE newsletters SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=OLD.newsletter_id;
END;
CREATE TRIGGER audit_guard_newsletter_event_items_insert BEFORE INSERT ON newsletter_event_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_event_items_insert AFTER INSERT ON newsletter_event_items
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_event_items','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'item_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.item_id),CAST(NEW.item_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT);
END;
CREATE TRIGGER audit_guard_newsletter_event_items_update BEFORE UPDATE ON newsletter_event_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_event_items_update AFTER UPDATE ON newsletter_event_items WHEN OLD.item_id IS NOT NEW.item_id OR OLD.kind IS NOT NEW.kind OR OLD.event_id IS NOT NEW.event_id
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_event_items','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'item_id',typeof(OLD.item_id),CAST(OLD.item_id AS TEXT),typeof(NEW.item_id),CAST(NEW.item_id AS TEXT) WHERE OLD.item_id IS NOT NEW.item_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT) WHERE OLD.kind IS NOT NEW.kind;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NEW.event_id),CAST(NEW.event_id AS TEXT) WHERE OLD.event_id IS NOT NEW.event_id;
END;
CREATE TRIGGER audit_guard_newsletter_event_items_delete BEFORE DELETE ON newsletter_event_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_event_items_delete AFTER DELETE ON newsletter_event_items
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_event_items','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'item_id',typeof(OLD.item_id),CAST(OLD.item_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'event_id',typeof(OLD.event_id),CAST(OLD.event_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_newsletter_initiative_items_insert BEFORE INSERT ON newsletter_initiative_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_initiative_items_insert AFTER INSERT ON newsletter_initiative_items
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_initiative_items','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'item_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.item_id),CAST(NEW.item_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT);
END;
CREATE TRIGGER audit_guard_newsletter_initiative_items_update BEFORE UPDATE ON newsletter_initiative_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_initiative_items_update AFTER UPDATE ON newsletter_initiative_items WHEN OLD.item_id IS NOT NEW.item_id OR OLD.kind IS NOT NEW.kind OR OLD.initiative_id IS NOT NEW.initiative_id
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_initiative_items','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'item_id',typeof(OLD.item_id),CAST(OLD.item_id AS TEXT),typeof(NEW.item_id),CAST(NEW.item_id AS TEXT) WHERE OLD.item_id IS NOT NEW.item_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT) WHERE OLD.kind IS NOT NEW.kind;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NEW.initiative_id),CAST(NEW.initiative_id AS TEXT) WHERE OLD.initiative_id IS NOT NEW.initiative_id;
END;
CREATE TRIGGER audit_guard_newsletter_initiative_items_delete BEFORE DELETE ON newsletter_initiative_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_initiative_items_delete AFTER DELETE ON newsletter_initiative_items
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_initiative_items','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'item_id',typeof(OLD.item_id),CAST(OLD.item_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'initiative_id',typeof(OLD.initiative_id),CAST(OLD.initiative_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER audit_guard_newsletter_campaign_items_insert BEFORE INSERT ON newsletter_campaign_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_campaign_items_insert AFTER INSERT ON newsletter_campaign_items
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_campaign_items','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'item_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.item_id),CAST(NEW.item_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT);
END;
CREATE TRIGGER audit_guard_newsletter_campaign_items_update BEFORE UPDATE ON newsletter_campaign_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_campaign_items_update AFTER UPDATE ON newsletter_campaign_items WHEN OLD.item_id IS NOT NEW.item_id OR OLD.kind IS NOT NEW.kind OR OLD.campaign_id IS NOT NEW.campaign_id
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_campaign_items','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'item_id',typeof(OLD.item_id),CAST(OLD.item_id AS TEXT),typeof(NEW.item_id),CAST(NEW.item_id AS TEXT) WHERE OLD.item_id IS NOT NEW.item_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT) WHERE OLD.kind IS NOT NEW.kind;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NEW.campaign_id),CAST(NEW.campaign_id AS TEXT) WHERE OLD.campaign_id IS NOT NEW.campaign_id;
END;
CREATE TRIGGER audit_guard_newsletter_campaign_items_delete BEFORE DELETE ON newsletter_campaign_items
WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1)
BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_newsletter_campaign_items_delete AFTER DELETE ON newsletter_campaign_items
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletter_campaign_items','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'item_id',typeof(OLD.item_id),CAST(OLD.item_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'campaign_id',typeof(OLD.campaign_id),CAST(OLD.campaign_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE TRIGGER guard_events_attribution_insert BEFORE INSERT ON events_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_events_attribution_update BEFORE UPDATE ON events_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_events_attribution_delete BEFORE DELETE ON events_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_initiatives_attribution_insert BEFORE INSERT ON initiatives_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_initiatives_attribution_update BEFORE UPDATE ON initiatives_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_initiatives_attribution_delete BEFORE DELETE ON initiatives_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_campaigns_attribution_insert BEFORE INSERT ON campaigns_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_campaigns_attribution_update BEFORE UPDATE ON campaigns_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_campaigns_attribution_delete BEFORE DELETE ON campaigns_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_newsletters_attribution_insert BEFORE INSERT ON newsletters_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_newsletters_attribution_update BEFORE UPDATE ON newsletters_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_newsletters_attribution_delete BEFORE DELETE ON newsletters_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_media_attribution_insert BEFORE INSERT ON media_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_media_attribution_update BEFORE UPDATE ON media_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER guard_media_attribution_delete BEFORE DELETE ON media_attribution WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER keep_audit_actions_update BEFORE UPDATE ON audit_actions BEGIN SELECT RAISE(ABORT,'Audit history is immutable'); END;
CREATE TRIGGER keep_audit_actions_delete BEFORE DELETE ON audit_actions BEGIN SELECT RAISE(ABORT,'Audit history is immutable'); END;
CREATE TRIGGER keep_audit_rows_update BEFORE UPDATE ON audit_rows BEGIN SELECT RAISE(ABORT,'Audit history is immutable'); END;
CREATE TRIGGER keep_audit_rows_delete BEFORE DELETE ON audit_rows BEGIN SELECT RAISE(ABORT,'Audit history is immutable'); END;
CREATE TRIGGER keep_audit_values_update BEFORE UPDATE ON audit_values BEGIN SELECT RAISE(ABORT,'Audit history is immutable'); END;
CREATE TRIGGER keep_audit_values_delete BEFORE DELETE ON audit_values BEGIN SELECT RAISE(ABORT,'Audit history is immutable'); END;
UPDATE gcf_schema SET version=4 WHERE id=1;
COMMIT;

BEGIN;
CREATE TABLE media_dimensions(media_id TEXT PRIMARY KEY REFERENCES media(id) ON DELETE CASCADE,width INTEGER NOT NULL CHECK(width>0),height INTEGER NOT NULL CHECK(height>0)) STRICT;
CREATE TABLE media_captures(media_id TEXT PRIMARY KEY REFERENCES media(id) ON DELETE CASCADE,local_datetime TEXT NOT NULL,utc_offset_minutes INTEGER CHECK(utc_offset_minutes BETWEEN -840 AND 840),source TEXT NOT NULL CHECK(source IN ('original','created','gps'))) STRICT;
CREATE INDEX media_captures_date ON media_captures(local_datetime,media_id);
CREATE TABLE media_coordinates(media_id TEXT PRIMARY KEY REFERENCES media(id) ON DELETE CASCADE,latitude REAL NOT NULL CHECK(latitude BETWEEN -90 AND 90),longitude REAL NOT NULL CHECK(longitude BETWEEN -180 AND 180),altitude REAL) STRICT;
CREATE TABLE media_place_names(media_id TEXT NOT NULL REFERENCES media(id) ON DELETE CASCADE,kind TEXT NOT NULL CHECK(kind IN ('location','city','region','country')),name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 300),PRIMARY KEY(media_id,kind)) STRICT;
CREATE INDEX media_place_names_name ON media_place_names(name);
CREATE TABLE media_metadata_scans(media_id TEXT PRIMARY KEY REFERENCES media(id) ON DELETE CASCADE,read_at TEXT NOT NULL) STRICT;
CREATE TRIGGER audit_guard_media_dimensions_insert BEFORE INSERT ON media_dimensions WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_dimensions_insert AFTER INSERT ON media_dimensions BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_dimensions','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'width',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.width),CAST(NEW.width AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'height',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.height),CAST(NEW.height AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_dimensions_update BEFORE UPDATE ON media_dimensions WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_dimensions_update AFTER UPDATE ON media_dimensions WHEN OLD.media_id IS NOT NEW.media_id OR OLD.width IS NOT NEW.width OR OLD.height IS NOT NEW.height BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_dimensions','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'width',typeof(OLD.width),CAST(OLD.width AS TEXT),typeof(NEW.width),CAST(NEW.width AS TEXT) WHERE OLD.width IS NOT NEW.width;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'height',typeof(OLD.height),CAST(OLD.height AS TEXT),typeof(NEW.height),CAST(NEW.height AS TEXT) WHERE OLD.height IS NOT NEW.height;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_dimensions_delete BEFORE DELETE ON media_dimensions WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_dimensions_delete AFTER DELETE ON media_dimensions BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_dimensions','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'width',typeof(OLD.width),CAST(OLD.width AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'height',typeof(OLD.height),CAST(OLD.height AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.media_id;
END;
CREATE TRIGGER audit_guard_media_captures_insert BEFORE INSERT ON media_captures WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_captures_insert AFTER INSERT ON media_captures BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_captures','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'local_datetime',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.local_datetime),CAST(NEW.local_datetime AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'utc_offset_minutes',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.utc_offset_minutes),CAST(NEW.utc_offset_minutes AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'source',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.source),CAST(NEW.source AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_captures_update BEFORE UPDATE ON media_captures WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_captures_update AFTER UPDATE ON media_captures WHEN OLD.media_id IS NOT NEW.media_id OR OLD.local_datetime IS NOT NEW.local_datetime OR OLD.utc_offset_minutes IS NOT NEW.utc_offset_minutes OR OLD.source IS NOT NEW.source BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_captures','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'local_datetime',typeof(OLD.local_datetime),CAST(OLD.local_datetime AS TEXT),typeof(NEW.local_datetime),CAST(NEW.local_datetime AS TEXT) WHERE OLD.local_datetime IS NOT NEW.local_datetime;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'utc_offset_minutes',typeof(OLD.utc_offset_minutes),CAST(OLD.utc_offset_minutes AS TEXT),typeof(NEW.utc_offset_minutes),CAST(NEW.utc_offset_minutes AS TEXT) WHERE OLD.utc_offset_minutes IS NOT NEW.utc_offset_minutes;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'source',typeof(OLD.source),CAST(OLD.source AS TEXT),typeof(NEW.source),CAST(NEW.source AS TEXT) WHERE OLD.source IS NOT NEW.source;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_captures_delete BEFORE DELETE ON media_captures WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_captures_delete AFTER DELETE ON media_captures BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_captures','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'local_datetime',typeof(OLD.local_datetime),CAST(OLD.local_datetime AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'utc_offset_minutes',typeof(OLD.utc_offset_minutes),CAST(OLD.utc_offset_minutes AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'source',typeof(OLD.source),CAST(OLD.source AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.media_id;
END;
CREATE TRIGGER audit_guard_media_coordinates_insert BEFORE INSERT ON media_coordinates WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_coordinates_insert AFTER INSERT ON media_coordinates BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_coordinates','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'latitude',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.latitude),CAST(NEW.latitude AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'longitude',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.longitude),CAST(NEW.longitude AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'altitude',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.altitude),CAST(NEW.altitude AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_coordinates_update BEFORE UPDATE ON media_coordinates WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_coordinates_update AFTER UPDATE ON media_coordinates WHEN OLD.media_id IS NOT NEW.media_id OR OLD.latitude IS NOT NEW.latitude OR OLD.longitude IS NOT NEW.longitude OR OLD.altitude IS NOT NEW.altitude BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_coordinates','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'latitude',typeof(OLD.latitude),CAST(OLD.latitude AS TEXT),typeof(NEW.latitude),CAST(NEW.latitude AS TEXT) WHERE OLD.latitude IS NOT NEW.latitude;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'longitude',typeof(OLD.longitude),CAST(OLD.longitude AS TEXT),typeof(NEW.longitude),CAST(NEW.longitude AS TEXT) WHERE OLD.longitude IS NOT NEW.longitude;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'altitude',typeof(OLD.altitude),CAST(OLD.altitude AS TEXT),typeof(NEW.altitude),CAST(NEW.altitude AS TEXT) WHERE OLD.altitude IS NOT NEW.altitude;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_coordinates_delete BEFORE DELETE ON media_coordinates WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_coordinates_delete AFTER DELETE ON media_coordinates BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_coordinates','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'latitude',typeof(OLD.latitude),CAST(OLD.latitude AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'longitude',typeof(OLD.longitude),CAST(OLD.longitude AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'altitude',typeof(OLD.altitude),CAST(OLD.altitude AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.media_id;
END;
CREATE TRIGGER audit_guard_media_place_names_insert BEFORE INSERT ON media_place_names WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_place_names_insert AFTER INSERT ON media_place_names BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_place_names','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'name',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.name),CAST(NEW.name AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_place_names_update BEFORE UPDATE ON media_place_names WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_place_names_update AFTER UPDATE ON media_place_names WHEN OLD.media_id IS NOT NEW.media_id OR OLD.kind IS NOT NEW.kind OR OLD.name IS NOT NEW.name BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_place_names','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NEW.kind),CAST(NEW.kind AS TEXT) WHERE OLD.kind IS NOT NEW.kind;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'name',typeof(OLD.name),CAST(OLD.name AS TEXT),typeof(NEW.name),CAST(NEW.name AS TEXT) WHERE OLD.name IS NOT NEW.name;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_place_names_delete BEFORE DELETE ON media_place_names WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_place_names_delete AFTER DELETE ON media_place_names BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_place_names','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'kind',typeof(OLD.kind),CAST(OLD.kind AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'name',typeof(OLD.name),CAST(OLD.name AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.media_id;
END;
CREATE TRIGGER audit_guard_media_metadata_scans_insert BEFORE INSERT ON media_metadata_scans WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_metadata_scans_insert AFTER INSERT ON media_metadata_scans BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_metadata_scans','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'read_at',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.read_at),CAST(NEW.read_at AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_metadata_scans_update BEFORE UPDATE ON media_metadata_scans WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_metadata_scans_update AFTER UPDATE ON media_metadata_scans WHEN OLD.media_id IS NOT NEW.media_id OR OLD.read_at IS NOT NEW.read_at BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_metadata_scans','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NEW.media_id),CAST(NEW.media_id AS TEXT) WHERE OLD.media_id IS NOT NEW.media_id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'read_at',typeof(OLD.read_at),CAST(OLD.read_at AS TEXT),typeof(NEW.read_at),CAST(NEW.read_at AS TEXT) WHERE OLD.read_at IS NOT NEW.read_at;
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.media_id;
END;
CREATE TRIGGER audit_guard_media_metadata_scans_delete BEFORE DELETE ON media_metadata_scans WHEN NOT EXISTS(SELECT 1 FROM audit_context WHERE singleton=1) BEGIN SELECT RAISE(ABORT,'Audited mutation context required'); END;
CREATE TRIGGER audit_capture_media_metadata_scans_delete AFTER DELETE ON media_metadata_scans BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'media_metadata_scans','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'media_id',typeof(OLD.media_id),CAST(OLD.media_id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'read_at',typeof(OLD.read_at),CAST(OLD.read_at AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 UPDATE media_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=OLD.media_id;
END;
UPDATE gcf_schema SET version=5 WHERE id=1;
COMMIT;

BEGIN;
ALTER TABLE newsletters RENAME TO publications;
ALTER TABLE publications ADD COLUMN format TEXT NOT NULL DEFAULT 'newsletter' CHECK(format IN ('article','newsletter'));
DROP TRIGGER audit_capture_newsletters_insert;
CREATE TRIGGER audit_capture_newsletters_insert AFTER INSERT ON publications
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'publications','insert');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'subject',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.subject),CAST(NEW.subject AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'introduction',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.introduction),CAST(NEW.introduction AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'body',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.body),CAST(NEW.body AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'format',typeof(NULL),CAST(NULL AS TEXT),typeof(NEW.format),CAST(NEW.format AS TEXT);
 INSERT INTO newsletters_attribution VALUES(NEW.id,(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)),(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)));
 UPDATE publications SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
DROP TRIGGER audit_capture_newsletters_update;
CREATE TRIGGER audit_capture_newsletters_update AFTER UPDATE ON publications WHEN OLD.id IS NOT NEW.id OR OLD.title IS NOT NEW.title OR OLD.subject IS NOT NEW.subject OR OLD.introduction IS NOT NEW.introduction OR OLD.body IS NOT NEW.body
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'publications','update');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NEW.id),CAST(NEW.id AS TEXT) WHERE OLD.id IS NOT NEW.id;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NEW.title),CAST(NEW.title AS TEXT) WHERE OLD.title IS NOT NEW.title;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'subject',typeof(OLD.subject),CAST(OLD.subject AS TEXT),typeof(NEW.subject),CAST(NEW.subject AS TEXT) WHERE OLD.subject IS NOT NEW.subject;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'introduction',typeof(OLD.introduction),CAST(OLD.introduction AS TEXT),typeof(NEW.introduction),CAST(NEW.introduction AS TEXT) WHERE OLD.introduction IS NOT NEW.introduction;
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'body',typeof(OLD.body),CAST(OLD.body AS TEXT),typeof(NEW.body),CAST(NEW.body AS TEXT) WHERE OLD.body IS NOT NEW.body;
 UPDATE newsletters_attribution SET updated_by=(SELECT actor_id FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE record_id=NEW.id;
 UPDATE publications SET updated_at=(SELECT occurred_at FROM audit_actions WHERE id=(SELECT action_id FROM audit_context WHERE singleton=1)) WHERE id=NEW.id;
END;
DROP TRIGGER audit_capture_newsletters_delete;
CREATE TRIGGER audit_capture_newsletters_delete AFTER DELETE ON publications
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'publications','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'subject',typeof(OLD.subject),CAST(OLD.subject AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'introduction',typeof(OLD.introduction),CAST(OLD.introduction AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'body',typeof(OLD.body),CAST(OLD.body AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'format',typeof(OLD.format),CAST(OLD.format AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
CREATE VIEW newsletters AS SELECT * FROM publications WHERE format='newsletter';
CREATE VIEW articles AS SELECT * FROM publications WHERE format='article';
CREATE VIEW articles_attribution AS SELECT a.* FROM newsletters_attribution a JOIN articles p ON p.id=a.record_id;
CREATE VIEW work_records AS
 SELECT id,title,summary,updated_at,'events' AS kind,'activity' AS work_type FROM events
 UNION ALL SELECT id,title,summary,updated_at,'campaigns','fundraiser' FROM campaigns
 UNION ALL SELECT id,title,summary,updated_at,'initiatives','campaign' FROM initiatives;
CREATE TRIGGER publication_format_immutable BEFORE UPDATE OF format ON publications WHEN NEW.format<>OLD.format
BEGIN SELECT RAISE(ABORT,'Publication format is immutable'); END;
UPDATE gcf_schema SET version=8 WHERE id=1;
COMMIT;

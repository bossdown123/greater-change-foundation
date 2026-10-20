BEGIN;
CREATE TABLE publication_revert_guard(value INTEGER CHECK(value=0));
INSERT INTO publication_revert_guard SELECT COUNT(*) FROM publications WHERE format='article';
DROP TABLE publication_revert_guard;
DROP TRIGGER publication_format_immutable;
DROP VIEW work_records;
DROP VIEW articles_attribution;
DROP VIEW articles;
DROP VIEW newsletters;
DROP TRIGGER audit_capture_newsletters_insert;
DROP TRIGGER audit_capture_newsletters_update;
DROP TRIGGER audit_capture_newsletters_delete;
ALTER TABLE publications DROP COLUMN format;
ALTER TABLE publications RENAME TO newsletters;
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
CREATE TRIGGER audit_capture_newsletters_delete AFTER DELETE ON newsletters
BEGIN
 INSERT INTO audit_rows(action_id,table_name,operation) VALUES((SELECT action_id FROM audit_context WHERE singleton=1),'newsletters','delete');
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'id',typeof(OLD.id),CAST(OLD.id AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'title',typeof(OLD.title),CAST(OLD.title AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'subject',typeof(OLD.subject),CAST(OLD.subject AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'introduction',typeof(OLD.introduction),CAST(OLD.introduction AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
 INSERT INTO audit_values SELECT (SELECT MAX(id) FROM audit_rows),'body',typeof(OLD.body),CAST(OLD.body AS TEXT),typeof(NULL),CAST(NULL AS TEXT);
END;
UPDATE gcf_schema SET version=7 WHERE id=1;
COMMIT;

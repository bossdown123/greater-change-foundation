BEGIN;
ALTER TABLE newsletters RENAME TO publications;
ALTER TABLE publications ADD COLUMN format TEXT NOT NULL DEFAULT 'newsletter' CHECK(format IN ('article','newsletter'));
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

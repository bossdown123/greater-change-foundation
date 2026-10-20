BEGIN;
SELECT id,format,title FROM publications WHERE 0;
SELECT id FROM articles WHERE 0;
SELECT id FROM newsletters WHERE 0;
SELECT record_id FROM articles_attribution WHERE 0;
SELECT id,kind,work_type FROM work_records WHERE 0;
SELECT CASE WHEN version=8 THEN 1 ELSE 1/0 END FROM gcf_schema;
ROLLBACK;

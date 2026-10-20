BEGIN;
DROP TABLE user_colors;
UPDATE gcf_schema SET version=5 WHERE id=1;
COMMIT;

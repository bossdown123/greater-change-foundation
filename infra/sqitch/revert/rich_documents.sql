BEGIN;
DROP TABLE event_inline_media;
DROP TABLE initiative_inline_media;
DROP TABLE campaign_inline_media;
DROP TABLE newsletter_inline_media;
UPDATE gcf_schema SET version=6 WHERE id=1;
COMMIT;

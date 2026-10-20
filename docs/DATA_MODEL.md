# Content model and normalization

The baseline schema uses atomic columns and relations rather than JSON records.
Every relation is at least 3NF: a non-key fact depends on its candidate key, not
on another non-key fact. Keys and dependencies are explicit below.

| Relation | Key / candidate keys | Facts depending on that key |
|---|---|---|
| events | id | title, story, participant count, amount in minor currency units, currency, timestamps |
| event_dates | (event_id, position); (event_id, event_date) | a date's position within an event |
| locations | id; name | the reusable location name |
| event_locations | (event_id, location_id); (event_id, position) | display order of a location in an event |
| field_definitions | id; (label, kind) | reusable label and immutable value kind |
| event_field_values | (event_id, field_id); (event_id, position) | one typed atomic value and its display order |
| media | id; storage_key; thumbnail_key | original filename, format, byte size, description, caption, creation time |
| event_media | (event_id, media_id); (event_id, position) | a reusable image's display order within an event |
| newsletters | id | authored draft title, subject, introduction, body, timestamps |
| newsletter_events | (newsletter_id, event_id); (newsletter_id, position) | selected event order |

Dates, locations, custom facts and image assignments vary independently. Separate
relations prevent their Cartesian product and avoid multivalued dependencies in
one event row. Shared location names and field definitions are stored once. A
field's kind determines which value column is permitted; triggers enforce this
without duplicating the kind in the value relation. Each fact row contains
exactly one non-null value, never a collection. Currency amounts use integer
minor units; API decimal values are derived. No event totals are cached in other
records.

A newsletter body is an independently authored document, initially generated
from selected events. It is intentionally a snapshot, not a second authoritative
store of event facts. Editing an event does not silently rewrite an edited draft;
the administrator can explicitly regenerate it. Gallery usage counts and image
URLs are derived rather than persisted.

Do not claim a higher normal form without checking actual dependencies. These
small relations have no currently identified non-key join dependency that calls
for a further 5NF decomposition. Temporal histories or independently changing
attributes may justify 6NF relations when introduced. State the precise proposed
meaning of 7NF before designing or asserting it, since that label is not uniform
in database literature.

## Migration safety

All changes use Sqitch deploy/revert/verify scripts. The admin schema is new, so
its initial migration creates normalized relations directly. A future correction
must migrate existing data, not merely rename JSON columns or drop populated
tables. Stage a backup and a lossless transformation, validate row counts,
foreign keys, uniqueness and typed values, and test recovery before switching
application reads. Larger migrations are preferred when necessary to correct
normalization. Revert scripts for initial schema creation remove their data;
production rollback must restore the pre-migration backup when content exists.

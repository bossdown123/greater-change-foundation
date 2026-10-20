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
| initiatives | id | initiative name, story, timestamps |
| campaigns | id | fundraising name/story, target and raised minor units, currency, optional dates, timestamps |
| initiative_events | (initiative_id, event_id); (initiative_id, position) | related event order |
| campaign_events | (campaign_id, event_id); (campaign_id, position) | explicitly linked event order |
| campaign_initiatives | (campaign_id, initiative_id); (campaign_id, position) | explicitly linked initiative order |
| newsletter_items | id; (newsletter_id, position) | selected update kind and mixed-type order |
| newsletter_event_items | item_id | source event foreign key, fixed event discriminator |
| newsletter_initiative_items | item_id | source initiative foreign key, fixed initiative discriminator |
| newsletter_campaign_items | item_id | source campaign foreign key, fixed campaign discriminator |

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

## Events, initiatives and fundraising campaigns

An event is a dated activity. An initiative describes ongoing work; a campaign
describes a fundraising effort with its own target and recorded progress. They
are distinct entities, not JSON types in a shared catch-all table. Their names
and stories are different facts even when similar. Many-to-many relations link
existing records without copying them. No implication is stored between an
initiative's events and a campaign's directly selected events: these are
different relationships. Event and campaign amounts are entered independently;
no sum or donation-level accounting is implied.

Newsletter selections have a common ordered parent and three typed association
relations. Composite foreign keys enforce the discriminator; each association
has one real foreign key rather than an unchecked polymorphic identifier.
Triggers prevent selecting the same source twice and clean up a selection when
its source is deleted. The application writes parent and typed child in one
transaction; verification asserts exactly one child per parent. Changing the
owner or type requires rebuilding the selection instead of partial edits. The
constant discriminator in each child exists to enforce the composite foreign
key, not as a second mutable copy of a source fact.

The `programmes` migration transforms old event-only newsletter selections into
this model while preserving original order and authored text. An automated
upgrade-and-reversal test checks that preservation. The initial and admin
verification scripts accept later schema versions; they verify the enduring
objects they introduced rather than requiring the whole schema to remain at an
old version.

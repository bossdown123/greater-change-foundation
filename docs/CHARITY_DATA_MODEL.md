# Charity work and publication views

## Decision

Store the charity's work once. An article and a newsletter are publication formats over selected work, with their own headline/subject, opening and closing prose. They do not own copies of event dates, places, fundraising totals or photo assignments.

The administration navigation is Work, Photos, Website and Newsletters. Work provides one list; its optional types are Activity, Fundraiser and Campaign / programme. These are not interchangeable concepts:

- An activity is something scheduled or carried out: a distribution, workshop, visit or fundraising event.
- A fundraiser is an appeal with an optional monetary goal, currency, reporting total and dates. It can fund or be supported by activities and broader work.
- A campaign is a coordinated effort towards a goal. A programme describes continuing service delivery; do not automatically claim that a historical initiative was a time-limited campaign. Existing broader records retain their identity and appear as Campaign / programme.
- A photo is a reusable media asset. Its caption, accessibility description and recorded capture metadata remain in the central library.
- An article is a website presentation of selected work. A newsletter is an email presentation of selected work. Both have independent editorial wording and ordering.

Fundraising totals are reported amounts, not individual donations, pledges, accounting entries or independently summable event totals. Do not add event and fundraiser totals together: they can overlap. Introducing a donation ledger later requires distinct contributions and allocations; this website does not invent one.

## Existing data and physical storage

Keep stable record IDs and all existing relationships. The legacy `events`, `campaigns` and `initiatives` tables already represent activities, fundraising appeals and broader work respectively. Their physical names are compatibility details; do not duplicate their facts into a second generic work table. A read-only `work_records` union is the common list projection.

Migration 8 renames the editorial `newsletters` table to `publications` and adds its format. The `newsletters` and `articles` read views select their respective formats. Existing source junctions and image references continue to reference the same publication IDs through SQLite's foreign-key-preserving rename. Existing newsletters remain newsletters.

`publications.id` determines format, editorial title, subject/headline, introduction, body and timestamps. Format is immutable after creation. Source membership and ordering remain relational in `newsletter_items` and the three typed source junctions. These legacy physical junction names apply to both formats. Each junction has a real foreign key, not a polymorphic string masquerading as one. Inline image references also retain foreign keys. Account attribution and append-only audit records remain intact.

This is at least 3NF: presentation prose depends on publication ID, source facts depend on their own work ID, and reusable media/location facts depend on their own IDs. Membership relations have independent composite keys and are not copied into JSON. Independent relations are separated where 5NF/6NF help. No unsupported claim of 7NF is made.

## View composition

A draft renders headline/subject, opening, the selected source records in order, and closing prose. Source records supply their current story, dates, places, reported results and photos. Editing source data updates draft views; editing publication wording does not change source records. Publications can be drafted without sources and connected later. They remain internal previews while the public site says GCF UNDER DEVELOPMENT.

New publications should use composition, not generate a permanent prose copy of facts. Legacy generated body text is preserved as authored content; it is not silently parsed or rewritten. A future publication feature must freeze reviewed output at publication/send time so subsequent source edits cannot rewrite a sent email or historical published release.

## Recovery

Take a database backup before migration. The ordinary revert restores the legacy table and refuses to proceed if article-format records exist, because removing their format would lose meaning. In that case recover the pre-migration backup or explicitly export/migrate those articles first. Never silently convert or delete articles for a rollback.

## Research

- [CiviCampaign](https://docs.civicrm.org/user/en/latest/campaign/what-is-civicampaign/) coordinates related activities, communications and fundraising towards a goal.
- [CiviEvent](https://docs.civicrm.org/user/en/latest/events/what-is-civievent/) separates events and participation from other work.
- [CiviContribute](https://docs.civicrm.org/user/en/latest/contributions/what-is-civicontribute/) distinguishes financial contributions from communications and events.
- [Open Referral HSDS](https://docs.openreferral.org/en/latest/hsds/schema_reference.html) distinguishes organizations, services, programmes and locations. It is a service-directory standard, not a complete charity CMS or fundraising ledger.

The GCF model is a deliberately smaller website-oriented interpretation of these sources, not a claim that every charity uses one universal schema.

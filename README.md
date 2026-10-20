# Greater Change Foundation

Public charity website and private collaborative member workspace. The public site
includes the foundation’s purpose, community work, five photo stories, updates,
support enquiries and contact details. Donations are handled as email enquiries;
no payment processor is configured. The GitHub Project stays empty for members.

- React + TypeScript/TSX, Vite, Tailwind CSS and shadcn/ui.
- Elixir + Ash, served by Phoenix/Bandit/Plug with realtime channels.
- Local Turso/libSQL on the existing Hetzner server; no Turso Cloud account required.
- Sqitch owns every schema change, including matching deploy/revert/verify SQL.
- [Blank GitHub Project](https://github.com/users/bossdown123/projects/7), linked to this repository.
  The project is private; add charity members through GitHub's project access settings.
- [Website](https://greaterchangefoundation.org).

## Design direction

Follow the [design principles](DESIGN_PRINCIPLES.md) for future website work:
content-led layouts, shallow markup, strongly discouraged nested cards,
independently selected UX primitives, thoughtful progressive disclosure, joint
mobile and desktop design, and creative use of supplied graphics.

## Run locally

Install Docker and its Compose plugin, then:

```sh
docker compose up -d --build
curl --fail http://localhost:4000/healthz
curl --fail http://localhost:4000/readyz
```

Open <http://localhost:4000>. The database has no published port and sits on an
internal Docker network. The frontend has no database token or credentials.
`/healthz` checks the web service; `/readyz` runs an Ash action which checks the
Turso schema. An unavailable or unmigrated database yields HTTP 503 on readiness.

## Migrations

```sh
docker compose run --rm migrate deploy --verify
docker compose run --rm migrate verify
# Destructive: use only when intentionally reversing schema changes.
docker compose run --rm migrate revert -y
```

Add each change to `infra/sqitch/sqitch.plan`, with matching SQL files in `deploy`,
`revert`, and `verify`. Do not use Ecto migrations or edit deployed SQL.

Sqitch's SQLite engine keeps its registry in a separate local `sqitch.db`. Its
client adapter sends application migration SQL to Turso's HTTP pipeline. Batches
stop at the first error; transactions roll back when the connection closes.
**Always back up and restore the registry and Turso database together.** Only one
migration process may run at once. Production deployments use `flock` to enforce
this. CI exercises deploy, verify, revert, and redeploy against a real libSQL server.

The single `gcf_schema` row is schema metadata, not charity content. Future
persistent domain features should use explicit Ash actions and parameterized SQL;
no public arbitrary SQL endpoint is exposed.

## Deployment

Pushes to `main` run the checks and build immutable app/migration images in GitHub
Actions. Successful checks deploy to the existing Hetzner host using SSH with
verified host keys. `DEPLOY_SSH_KEY` and `DEPLOY_KNOWN_HOSTS` are GitHub Actions
secrets; `DEPLOY_HOST` is a repository variable. Registry credentials exist only
for the deployment and are removed afterward.

Production configuration is `deploy/compose.yaml`. Source/configuration resides
at `/opt/greater-change-foundation`, persistent state at `/var/lib/gcf` (a symlink
to the existing mounted Hetzner volume), and
pre-deployment backups at `/var/backups/gcf`. Caddy obtains HTTPS certificates
for the charity domain. Only web ports and SSH need to be public; the app's
port 4000 is loopback-only and the database has no host port.

Deploying stops the app and database briefly to take a consistent paired backup.
Migrations must succeed before the new application starts. A failed migration
stops deployment: inspect it and restore service deliberately; do not repeatedly
retry unknown schema failures. Before initial deployment, FleetLog is backed up
and disabled separately; normal GCF releases never touch other projects.

## Recovery

FleetLog is retained privately; its old repository history is never copied here.
Its database dump, configuration and offline data archive are kept under
`/var/backups/fleetlog` on the server. Do not publish these archives.

For a GCF database rollback: stop the app and database, save the current state,
restore **both** `database/` and `sqitch/` from the same archive, and redeploy the
matching prior commit. For a code-only rollback with a compatible schema, rerun
the last successful GitHub Actions workflow or revert the source change and push.
The previous image references are retained in the server's `.env.previous`.

## References

- [Ash actions](https://ash.hexdocs.pm/actions.html)
- [Turso SQL over HTTP](https://docs.turso.tech/sdk/http/reference)
- [Sqitch SQLite engine](https://sqitch.org/docs/manual/sqitch-engine/)

## Administration

`/admin` provides a password-protected workspace with a shadcn left sidebar,
a work area with header search and a resizable inspector that opens on selection. Phones use
Edit/Preview views and drawer navigation. The sections are:

- **Work:** activities, fundraisers and broader campaigns/programmes. Dates,
  locations, financial facts and reusable photo selections stay with the source
  record and are linked rather than copied into publications.
- **Website:** draft articles composed from shared work, rich text and images.
- **Image library:** private uploads, image descriptions, captions, recorded
  metadata, usage information and reusable selections. Removing a photo from a
  story does not remove its library original.
- **Newsletters:** ordered shared work with editable opening/closing content,
  live previews and HTML/plain-text exports. Email delivery and subscriber
  management are not configured.
- **History** and **People:** attributed audit history and administrator-managed
  member accounts.

Public pages use a curated selection of supplied GCF photographs and verified
copy. Admin drafts and library originals remain private: editing an article does
not publish it. See [public website content and rendering](docs/PUBLIC_WEBSITE.md)
for provenance, the public/private boundary and the future release workflow.

See [the relational model](docs/DATA_MODEL.md) for normalization and migration
requirements. `AGENTS.md` requires at least 3NF, appropriate higher normalization,
and substantial migrations when needed to fix the data model.

### Local harness

Run `./bin/dev`, then open `http://127.0.0.1:4173/` for the website or
`http://127.0.0.1:4173/admin` for the member workspace. This starts **local**
Turso, a **local** Garage image bucket, the Elixir API and a Vite frontend with
hot reload. It does not connect to production or require a remote bucket.
Docker downloads and npm installation require internet on first setup; normal
local data and upload operations are independent of the production server.

The initial password is saved in the ignored `.admin-password` file. Never
commit `.env` or this password. Database and image files persist in the local
`gcf_database`, `gcf_media` and `gcf_sqitch` Docker volumes. Local media is separate
from production. `./bin/dev-stop` stops services without deleting data. Run
`./bin/dev` again after backend changes to rebuild the API and apply migrations.
The full built app is also available at `http://127.0.0.1:4000`.

Do not use `docker compose down -v` unless you intentionally want to erase local
data. The harness refuses a remote database URL override. The API's S3 endpoint
is explicitly set to the local `storage` service in Compose.

The private `gcf-media` bucket uses Garage, an S3-compatible service on the
existing server. Production assigns a 5 GB quota. Only the app connects to it;
there is no public bucket or exposed S3 administration port. Full originals and
smaller WebP previews persist under `/var/lib/gcf/media` on the attached volume.
The app holds the bucket credentials and enforces authenticated access.

### Production configuration and recovery

The server must have `/opt/greater-change-foundation/.secrets.env` (mode 600),
containing `GCF_SESSION_SECRET`, `GCF_ADMIN_PASSWORD_HASH`, `GARAGE_RPC_SECRET`,
`S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `GARAGE_DEFAULT_ACCESS_KEY` and
`GARAGE_DEFAULT_SECRET_KEY`. The Garage defaults must match the S3 credentials.
Use `deploy/local-secrets.py` to generate the format; transfer only the secret
fields into the server file. This file survives releases and is never in Git.
Production cookies require HTTPS; local Compose explicitly allows HTTP cookies.
The password hash uses PBKDF2-SHA256 with a random salt and 600,000 iterations.

Database backups are taken before migrations. Garage maintains metadata
snapshots, but both its data and metadata are needed for recovery. Back up
`/var/lib/gcf/media` together with database/registry state to a separate machine
or external backup service; the single server and attached volume do not provide
independent disaster recovery. Do not change Garage keys or wipe its metadata
while retained originals are in use. Recovery must restore media metadata/data,
Turso data, Sqitch state and matching secrets.

### Verification

`npm run build` in `apps/web` checks TypeScript, builds the frontend and prerenders
the public pages. `node public-site.test.mjs` checks public navigation, search,
photo viewing and rendered metadata. With the built application running,
`python3 infra/tests/public_website.py` checks every public route and the private
workspace boundary. CI runs these alongside the existing checks below.


`python3 infra/tests/normalization.py` verifies relational constraints and schema
reversal. With the app running, `python3 infra/tests/admin_smoke.py` checks actual
sign-in, CSRF rejection, image storage/readback, event relations, shared-image
usage, newsletter generation/persistence and cleanup. CI runs both, in addition
to Elixir tests, the frontend build and Sqitch's Turso deploy/revert/verify cycle.

### Named administrator accounts and history

Set `GCF_ADMIN_EMAIL` before the first schema-4 application start. The existing
`GCF_ADMIN_PASSWORD_HASH` initializes that account only when `users` is empty;
authentication then uses the database account. Local first-time setups default
to `admin@example.test`. Existing shared-password cookies are invalidated.

Administrators can manage named Administrator/Editor accounts under People.
Editors manage content and read history; only administrators manage accounts.
Disable accounts instead of deleting them. A password, email, access or active
status change revokes existing sessions; changing your own password signs you
out. No invitation or email-reset delivery is configured.

History provides filtered, paginated actions and relational before/after values.
Each content record retains its creator and latest modifier. Ash establishes the
authenticated actor, and database guards ensure that writes and audit records
commit together. See `docs/DATA_MODEL.md` for guarantees and migration recovery.

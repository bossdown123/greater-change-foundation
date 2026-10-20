# Greater Change Foundation

Public charity website starter. The only public page says **GCF UNDER DEVELOPMENT**.
No donation flow, member accounts, charity content, issues, or project tasks are seeded.

- React + TypeScript/TSX, Vite, Tailwind CSS and shadcn/ui.
- Elixir + Ash, served by Bandit/Plug.
- Local Turso/libSQL on the existing Hetzner server; no Turso Cloud account required.
- Sqitch owns every schema change, including matching deploy/revert/verify SQL.
- [Blank GitHub Project](https://github.com/users/bossdown123/projects/7), linked to this repository.
  The project is private; add charity members through GitHub's project access settings.
- [Website](https://greaterchangefoundation.org).

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

# Greater Change Foundation

- Commit frequently after meaningful, verified checkpoints.
- Keep the public page limited to “GCF UNDER DEVELOPMENT” until requested otherwise.
- Backend: Elixir and Ash; frontend: React TSX, Tailwind CSS, shadcn/ui.
- Database: Turso/libSQL; all schema changes use Sqitch deploy/revert/verify scripts.
- Keep credentials, database files, backups, and deployment state out of Git.
- Prefer Docker Compose for reproducible tooling and deployment.
- Keep the GitHub Project empty until charity members add their own work.

## Website design

Read and follow [DESIGN_PRINCIPLES.md](DESIGN_PRINCIPLES.md) before making website
design or interaction decisions. Its requirements include:

- Open, content-led layouts; cards and bordered containers are not the default.
- Shallow semantic markup with minimal wrappers. Strongly discourage cards
  inside cards and avoid repeated container nesting.
- A dedicated subagent must choose UX primitives for new or materially changed
  interactions. Give it only an abstract use case and necessary context, not a
  proposed component, existing markup, or preferred layout.
- Progressive information reveal through appropriate disclosures, sidebars,
  dropdowns, or tabs, while keeping most charity information visible by default.
- Joint mobile and desktop design, with high responsiveness and accessible
  interactions on both.
- Creative, purposeful use of supplied graphics.

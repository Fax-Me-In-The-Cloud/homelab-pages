# Homelab documentation style & structure guide

How to **write, edit, and review** the documentation in this repository. The
docs are an MkDocs Material site published to GitHub Pages; the goal is a
runbook a future me (or anyone) can follow to build, rebuild, and maintain the
homelab from bare hardware to running services.

## Structure

The docs are organised **by stack layer**, and the `nav:` in `mkdocs.yml`
mirrors the build order in `index.md` (Terminal → k3s → HTTPS → Authentication
→ DNS → Observability → Home Automation → Media).

- **One directory per area** under `docs/<area>/`; **one page per service**,
  filename = topic (`longhorn.md`, `authentik.md`).
- **`index.md` is the hub, not a service page.** It owns the single source of
  truth for topology — the stack table, nodes table, network-layout table, and
  build order. Change `index.md` first whenever hardware, IPs, or services
  change; service pages must agree with it.
- **Manifests and config live as sibling files** (`.yaml`, `.toml`, `.py`) next
  to the page and are referenced/applied by name. Do not paste large manifests
  inline — link or include them (`pymdownx.snippets`) so the page stays
  readable and the file stays the source of truth.
- **Every page is registered in `mkdocs.yml` nav**, under the right layer, in
  build order. A page that isn't in nav is unreachable in the built site.

## Page anatomy — the runbook pattern

Each service page follows the same shape:

1. **H1 = service name.**
2. **One or two opening sentences:** what it is and its role in the stack.
3. **Prerequisites** — only when there are any.
4. **Install / Deploy** — imperative, copy-pasteable commands
   (`kubectl apply -f <file>`, `helm …`).
5. **Verify** — the commands to confirm success, *with the expected output*
   ("look for these lines…").
6. **Troubleshooting** — common failure → fix (e.g. the scale-to-zero rollout
   idiom for stuck deployments).
7. **Upgrade / Uninstall** where relevant; sub-features as `##`/`###`.

## Voice & style

- **First person, concise, direct** — this is "my homelab"; use the imperative
  mood for steps ("Create the namespace", not "You should create…").
- **Explain the "why"** for any non-obvious decision in a callout, not just the
  "what". The rationale is the part that ages well.
- **No "Step N" numbering.** Use descriptive headings and implied top-down
  order; cross-reference sections by name.

## Formatting (MkDocs Material / pymdownx)

- **Callouts: pick one convention and keep it consistent.** Today the docs use
  `>` blockquotes for Critical/Note/gotcha. Material admonitions (`!!! note`)
  are the alternative — do not mix the two in a page.
- **Fenced code blocks carry a language tag** and stay copy-clean — no leading
  `$` prompts, since `content.code.copy` is enabled.
- **One command per line — no `\` continuations.** Keep each shell command on a
  single line, however long. Wrapped commands with trailing backslashes are
  awkward to copy from a terminal.
- **Tables for inventories** — nodes, network layout, entity/IP/helper
  mappings.

## Secrets & environment specifics

- State concrete IPs and hostnames, but they **must match `index.md`'s network
  table** — that table is the single source of truth for topology.
- **Never inline a secret value.** Reference secrets by their location (a
  Kubernetes Secret name, a file path), and show `kubectl create secret …`
  using placeholders, never real values.

## Review checklist

Before merging a docs change, confirm:

- [ ] Page is in `mkdocs.yml` nav, under the right layer, in build order
- [ ] Follows the runbook anatomy (intro → deploy → verify → troubleshoot)
- [ ] Commands are copy-pasteable and current (image tags, versions, IPs)
- [ ] Verify section shows the expected output
- [ ] No inline secrets; environment specifics agree with `index.md`
- [ ] **Internally consistent** — no header, label, or claim contradicted by the
      surrounding content or by a change made elsewhere; fix such inconsistencies
      even when not explicitly flagged
- [ ] Code blocks are single-line commands (no `\` continuations)
- [ ] Deprecated or removed components are pruned — not left as stale pages or
      manifests
- [ ] Markdown lints clean
- [ ] `mkdocs build --strict` passes (catches broken nav entries and links)

## Editing workflow

- Branch per change; open a PR to `main` (the security scan runs on every PR).
- Preview with `mkdocs serve`; run **`mkdocs build --strict` before opening a
  PR** to catch nav/link breakage.
- Update `index.md` whenever topology or build order changes.

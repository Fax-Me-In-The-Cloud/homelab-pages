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
  single line; never wrap it with a trailing backslash (awkward to copy from a
  terminal). If a command becomes very long or wide, prefer **splitting the work
  into several shorter commands** where possible — e.g. capture an intermediate
  value in a variable on one line, then use it on the next — rather than one
  unwieldy line.
- **Tables for inventories** — nodes, network layout, entity/IP/helper
  mappings.

## Long code blocks — include or reference the file, don't inline it

For anything longer than a short snippet (full Kubernetes manifests, Helm
values, config files, scripts), keep the file as a **sibling next to the page**
and pull it in, so the rendered content can never drift from the real file.
Two ways, both verified working with this repo's `mkdocs.yml`:

- **Include** — embed the file's live content as a highlighted block. Wrap a
  `pymdownx.snippets` directive in a fenced block. **Paths are relative to
  `docs/`** (not to the page):

  ````text
  ```yaml title="matter_server.yaml"
  --8<-- "home_assistant/matter_server.yaml"
  ```
  ````

- **Reference** — link to the raw file; MkDocs copies sibling files into the
  built site, so a relative link resolves:

  ```text
  [matter_server.yaml](matter_server.yaml)
  ```

Snippet gotchas — these are why an include can silently do nothing:

- The path resolves against `pymdownx.snippets` `base_path` in `mkdocs.yml`
  (`docs/`, then the repo root), **not** relative to the page. `--8<-- "./file"`
  does **not** work; use the path from `docs/` (e.g. `terminal/starship/starship.toml`).
- `check_paths: true` is enabled, so a wrong path is a **hard build error**, not
  a silent skip — `mkdocs build --strict` catches it before it ships.
- Put the `--8<--` line **inside a fenced code block** with a language so it
  renders highlighted; a bare directive dumps raw text.

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

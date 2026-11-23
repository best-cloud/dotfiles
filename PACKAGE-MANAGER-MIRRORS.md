# Package-manager mirror portability

Lockfiles pin exact versions and hashes, but some also pin the exact **URL** a
package was downloaded from. When the mirror is baked into the lockfile, anyone
else (CI in another region, contributors abroad) is forced through that mirror.

This note records, per package manager, how to keep the mirror on the machine
that needs it while the committed lockfile stays canonical. It is the follow-up
list for the uv `proxy-index` migration: revisit each section when that feature
ships. Context is in [uv (the trigger)](#uv-the-trigger).

Status: 2026-11-23. The chezmoi-managed mirrors are TUNA for PyPI and npmmirror
for npm (see "PyPI, Homebrew and npm mirrors" in `README.md`).

## The three designs

| Design | Lockfile stores | Registry chosen by | Examples |
| --- | --- | --- | --- |
| URL-free lock | versions + hashes | install-time config | pnpm, Yarn Berry, pip, Go |
| Canonical URL, rewritten on fetch | canonical URLs | client config rewrites the host | npm `replace-registry-host`, uv `proxy-index`, Bundler `mirror.*` |
| Mirror baked into the lock | mirror URLs | lockfile hard-codes the mirror | npm custom registry, Yarn 1, Poetry, uv today |

The second design is what uv is adding. The first is equivalent in practice and
needs no new feature. The third is the one this note exists to avoid.

## uv (the trigger)

Current state: `dot_config/uv/uv.toml` (Unix) and
`AppData/Roaming/uv/uv.toml` (Windows) set TUNA as the default index with a plain
`[[index]]` entry. That bakes `mirrors.tuna.tsinghua.edu.cn` into every
`uv.lock`, and `uv sync --frozen`/`--locked` downloads from those recorded URLs
regardless of the index configuration (astral-sh/uv#19625), so CI pays for the
mirror.

Target state (uv's "proxy index" preview, astral-sh/uv#20790, merged
2026-11-17): resolve and download through TUNA while the lockfile records
`pypi.org` and `files.pythonhosted.org`. Both `uv.toml` copies get:

```toml
preview-features = ["proxy-index"]

[[index]]
name = "pypi"
url = "https://pypi.org/simple/"
default = true

[[proxy-index]]
name = "tuna"
url = "https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple/"
artifact-base-url = "https://mirrors.tuna.tsinghua.edu.cn/pypi/web/packages/"
proxy-for = "pypi"
```

Notes:

- Proxy indexes are a preview feature; enable it with
  `preview-features = ["proxy-index"]` (or `--preview`) and drop the key once it
  stabilizes.
- uv requires the path after each artifact base to match on both servers. TUNA
  and PyPI both use `packages/<xx>/<yy>/<hash>/<file>`, and PyPI's artifact base
  (`https://files.pythonhosted.org/packages/`) is uv's built-in default for the
  `pypi` index, so no extra setting is needed for the upstream side.
- Keep the proxy in the **user-level** `uv.toml`, never in a project's
  `pyproject.toml`: a proxy configured in the project would be committed.
- Blocker: the newest release at the time of writing is uv 0.13.9 (published
  2026-11-17 09:57 UTC), which predates the merge and rejects
  `[[tool.uv.proxy-index]]` with `unknown field 'proxy-index'`. Wait for the next
  release, or build from `main`.

Checklist (do when a supporting uv is released):

- [ ] Upgrade uv and confirm `[[proxy-index]]` parses.
- [ ] Replace the TUNA `[[index]]` in both `uv.toml` copies with the block above.
- [ ] Update `README.md` and `AGENTS.md` (mirror rules live in both).
- [ ] Run `uv lock` in each project; `git diff uv.lock` must show only
      `mirrors.tuna…` -> `pypi.org`/`files.pythonhosted.org`.
- [ ] Validate with a frozen install on a clean cache **without** the proxy
      (CI or a scratch machine).
- [ ] Remove the `preview-features` line once proxy indexes are stable.

Interim option if CI speed matters before the release: generate locks against
the upstream index (`UV_DEFAULT_INDEX=https://pypi.org/simple uv lock`), scoped to
the command so it cannot leak into a later lock, and accept that dev installs
then use `files.pythonhosted.org`.

## npm

npm treats the literal default registry in a lockfile as a sentinel. From the
npm registry docs:

> When the default registry is used in a package-lock or shrinkwrap it has the
> special meaning of "the currently configured registry". If you create a lock
> file while using the default registry you can switch to another registry and
> npm will install packages from the new registry, but if you create a lock file
> while using a custom registry packages will be installed from that registry
> even after you change to another registry.

Consequences:

- `replace-registry-host` (default `npmjs`) rewrites `registry.npmjs.org` URLs in
  the lock to the configured registry at install time. A **canonical** lock
  therefore works with npmmirror locally, but a lock written **through**
  npmmirror stays pinned to it. The default is asymmetric.
- `omit-lockfile-registry-resolved=true` (npm 8.15+) writes the lock without a
  `resolved` key for registry dependencies, so both dev and CI resolve the
  tarball against their configured registry. This is the closest npm equivalent
  of uv `proxy-index`; it costs a manifest fetch per package on install.

Recommended setup for a project that needs a portable lock:

```ini
# .npmrc (committed)
omit-lockfile-registry-resolved=true
# registry stays out of the project; keep it in the user .npmrc or env
```

or generate the lock against the upstream registry once:
`npm install --registry=https://registry.npmjs.org`.

Do not rely on `replace-registry-host=always`; it only works if every machine
sets it, and it rewrites the host to whatever registry that machine uses.

## pnpm

`pnpm-lock.yaml` stores `resolution: { integrity: … }` and omits the tarball URL
when the registry uses the canonical npm layout, so the lock is already
registry-agnostic. pnpm 11.23 documents registry-layout detection deciding
whether a URL can be omitted; a non-canonical layout gets an explicit `tarball`.

Action: none expected. If pnpm is ever adopted, keep `registry` in user config
and check that registry dependencies have no `tarball:` entry.

## Yarn

- **Yarn 1 (Classic)** stores the full `resolved` URL in `yarn.lock`, so the
  registry is baked in. Regenerating against the canonical registry is the only
  clean fix; prefer Yarn Berry.
- **Yarn 2+ (Berry)** stores `resolution: "pkg@npm:1.2.3"` plus `checksum`, with
  no URL, and selects the registry from `npmRegistryServer` /
  `YARN_NPM_REGISTRY_SERVER`. This is URL-free by design: keep
  `npmRegistryServer` in user config (or the environment) and commit only the
  lock.

## pip and `uv pip`

`requirements.txt` with `--generate-hashes` records filenames and hashes, not
registry URLs (direct URL dependencies are the exception), and the index is a
command-line or `PIP_INDEX_URL` setting. This is URL-free by design, so a TUNA
mirror locally and PyPI in CI already work.

Escape hatch while uv `proxy-index` is unavailable:
`uv export --format requirements-txt --generate-hashes > requirements.txt`, then
install per machine with `--index-url`/`UV_DEFAULT_INDEX`. It loses `uv sync`'s
environment management but gives a portable, hash-pinned install.

`uv pip compile --format pylock.toml` records the upstream index in
`packages.index` for proxied files, which is what lets `uv pip install` use a
proxy with a proxied `pylock.toml`.

## Poetry

Poetry records a configured source in `poetry.lock` as a `[package.source]`
table with the mirror URL (`type = "legacy"`, `url = …`), so a mirror configured
as a project source is baked into the lock. There is still an open request to
override the source URL per environment (python-poetry/poetry#1632).

Action: nothing clean today. If a Poetry project must stay portable, lock against
the canonical index and accept slower installs, or use the pip-style export.

## Cargo

`Cargo.lock` records `source = "registry+https://github.com/rust-lang/crates.io-index"`.
A mirror is applied through source replacement in `.cargo/config.toml`:

```toml
[source.crates-io]
replace-with = "tuna"

[source.tuna]
registry = "sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"
```

Replacement is transparent, so the lockfile stays canonical and CI is unaffected.
Caveat: the replacement must be 1:1 with crates.io (same packages and versions),
because the checksums must match.

## Go

`go.sum` stores module path, version and hashes only; the proxy is chosen at
install time with `GOPROXY` (e.g. `https://goproxy.cn` locally,
`https://proxy.golang.org` in CI). Nothing to change; this is the URL-free model
by default.

## Bundler

`Gemfile.lock` keeps `remote: https://rubygems.org/` and `source "…"` in the
`Gemfile`; a mirror is applied per machine with:

```sh
bundle config set --global mirror.https://rubygems.org https://mirror.example/
```

Bundler redirects downloads to the mirror without touching the lockfile, so the
same lock builds everywhere. This is the closest existing analogue of uv's
`proxy-index`.

## When uv `proxy-index` ships

Consolidated follow-up list:

- [ ] uv: migrate both `uv.toml` copies (see the checklist above).
- [ ] npm: add `omit-lockfile-registry-resolved=true` to projects whose lock must
      stay portable, or lock against `registry.npmjs.org`.
- [ ] Yarn: prefer Berry for new projects; do not write locks through a mirror.
- [ ] Poetry: keep the mirror out of `pyproject.toml`; lock against PyPI.
- [ ] Cargo/Go/Bundler: document the per-machine mirror command in the project
      README instead of the lock.
- [ ] Re-read this note after the uv release and delete the interim advice.

## References

- uv proxy indexes: <https://github.com/astral-sh/uv/pull/20790>,
  <https://docs.astral.sh/uv/concepts/indexes/#proxy-indexes> (docs on `main`;
  the published site lags until the next release)
- uv lockfile URL portability: <https://github.com/astral-sh/uv/issues/6349>
- `uv sync --frozen` hard-coded URLs: <https://github.com/astral-sh/uv/issues/19625>
- npm config (`registry`, `replace-registry-host`,
  `omit-lockfile-registry-resolved`): <https://docs.npmjs.com/cli/v12/using-npm/config>
- npm registry sentinel rule: <https://docs.npmjs.com/cli/v12/using-npm/registry>
- npm `omit-lockfile-registry-resolved` PR: <https://github.com/npm/cli/pull/4874>
- pnpm lockfile format: <https://pnpm.io/lockfile>
- pnpm tarball URL omission: <https://pnpm.io/blog/releases/11.23>
- Yarn Berry `npmRegistryServer`: <https://yarnpkg.com/configuration/yarnrc#npmRegistryServer>
- Poetry per-environment source override: <https://github.com/python-poetry/poetry/issues/1632>
- Cargo source replacement: <https://doc.rust-lang.org/cargo/reference/source-replacement.html>
- Go modules and `GOPROXY`: <https://go.dev/ref/mod#goproxy-protocol>
- Bundler `mirror.*`: <https://guides.rubygems.org/command-reference/bundle-config/>

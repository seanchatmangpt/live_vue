# LiveVue v26.8.27 Cloud Build Audit

Audit date: 2026-08-27

## Identity

- Repository: `seanchatmangpt/live_vue`
- Admitted base: `main@6ea7b146d66eac54506f196cc0982229083a7755`
- Base tree: `d359e53c6edc776fa05becbafc90451373ca5a55`
- Upstream-equivalent subject: `Valian/live_vue@6ea7b146d66eac54506f196cc0982229083a7755`
- Audit/migration branch: `feat/phoenix-ash-nitro-v26.8.27`

No base movement is implied by this audit.

## O / O*

### Observed

- LiveVue 1.2.3 source at the exact base SHA.
- Root development doctrine and existing test commands.
- Elixir/Phoenix library code, Vue/TypeScript bridge, SSR implementations, Vite plugin, Igniter installer, CI workflow definitions, guides and representative frontend tests.
- Current fork has no recorded GitHub Actions runs for the exact base SHA.
- The exact same source SHA in `Valian/live_vue` has successful Elixir CI, Frontend CI and E2E workflow runs dated 2026-08-24.
- Cloud execution container has Node.js `v22.16.0`, npm `10.9.2`, Git `2.47.3` and a global TypeScript compiler.
- Cloud execution container does not currently expose `elixir`, `mix`, `erl`, `rebar`, `asdf` or `mise`.
- DNS resolution for `github.com` is unavailable inside the container; direct `git clone` therefore fails.
- System package-index refresh is also unavailable from the container, so the missing BEAM toolchain cannot be lawfully installed from the network during this court.

### Admitted

- Exact GitHub objects read through the authorized GitHub connector.
- The root `AGENTS.md` doctrine.
- Exact base SHA above.
- Existing project commands as acceptance courts: `mix test`, `npm test`, `npm run e2e:test`, with frontend type checking and the existing CI matrices as supporting courts.
- A dependency-closed local TypeScript slice is admissible only as a component court, not as proof of the entire project.

## Source review

### Existing architecture that is already strong

1. **LiveView remains authoritative.** The server owns state and transports incremental changes through LiveView rather than creating a parallel fetch loop.
2. **Vue remains a real client runtime.** LiveVue uses Vue reactivity, hydration, composables, plugins and the component ecosystem rather than reducing Vue to server templates.
3. **The diff path is sophisticated.** LiveView `__changed__`, server-side JSON Patch construction, compact patch transport and in-place Vue reactive patching already provide a strong payload-update architecture.
4. **Streams are native.** LiveView streams are converted to compact upsert/remove/limit operations instead of being flattened into generic arrays and polling.
5. **SSR already has a BEAM-native production option.** QuickBEAM executes the generated Vue SSR bundle inside the BEAM, with NodeJS retained as a compatibility mode and ViteJS as the development mode.
6. **Development integration is already ergonomic.** The Vite plugin provides SSR loading, `.ex`/`.heex` HMR invalidation and manifest support.
7. **Installation is already an Igniter composition.** `mix live_vue.install` composes PhoenixVite installation and modifies Phoenix/Vite/Tailwind/SSR configuration through an Elixir-native installer.

These are preservation fences for the Phoenix/Ash migration.

## Nuxt/Nitro migration review

The migration target is **developer affordance equivalence**, not Nitro runtime equivalence.

| Nitro/Nuxt affordance | Phoenix/Ash destination | Base status |
| --- | --- | --- |
| server/API handlers | Ash actions + Phoenix routes/controllers/LiveView | Phoenix side ALIVE; Ash projection UNSUPPORTED |
| typed server operations | AshTypescript-generated action contracts + LiveVue transport adapter | UNSUPPORTED |
| route rules | Spark-validated LiveVue route policy projected into Phoenix/SSR/cache | UNSUPPORTED |
| runtime config | Application config/runtime.exs + typed public projection | Phoenix mechanism ALIVE; LiveVue facade UNSUPPORTED |
| server tasks | Reactor + AshOban/Oban | external ecosystem capability; LiveVue integration UNSUPPORTED |
| cache functions | action/actor/tenant-aware cache policy | UNSUPPORTED and intentionally fenced |
| universal KV storage | Ash resources/data layers or explicit cache/blob adapters | intentionally NOT copied as ambient storage |
| WebSockets | Phoenix LiveView/Channels/PubSub | ALIVE; no migration required |
| SSR | LiveView dead render + ViteJS/NodeJS/QuickBEAM | ALIVE at source baseline |
| HMR | Phoenix reload + Vite HMR + LiveVue plugin | ALIVE at source baseline |
| plugin system | Spark extensions + OTP supervision + Telemetry | LiveVue-specific extension model UNSUPPORTED |
| OpenAPI/API generation | AshJsonApi/OpenAPI projection | external ecosystem capability; integration UNSUPPORTED |

## Cloud-container execution

### Transport / toolchain orientation

Observed commands:

```text
command -v elixir   -> not found
command -v mix      -> not found
command -v erl      -> not found
node --version      -> v22.16.0
npm --version       -> 10.9.2
git --version       -> git version 2.47.3
getent hosts github.com -> no result
```

Direct materialization via Git was attempted and failed because the container could not resolve `github.com`.

The BEAM court is therefore:

`BLOCKED:TOOLCHAIN_TRANSPORT`

This is not `BUILD_BROKEN`: no admitted Elixir runtime reached `mix deps.get`, `mix compile` or `mix test` in this container.

### Executed frontend component court

A dependency-closed slice of the exact `assets/compactPatch.ts` implementation was reconstructed from the admitted source. The imported `Operation` declaration was replaced locally by a type-only test stub so that the function could be compiled without downloading the project dependency graph. No production repository file was changed by this probe.

Executed:

```text
tsc --target ES2022 --module NodeNext --moduleResolution NodeNext --strict \
  --outDir dist compactPatch.ts jsonPatch.ts probe.ts

node dist/probe.js
```

Result:

```text
frontend-probe: ALIVE
```

Hashes from the court:

```text
compactPatch.ts
61fab47698dbb6da595b83bd698ce5fbb018d73338f4db75e4857005644f45f4

dist/compactPatch.js
311a52e6776cd34c4b040d8733a99b948b6b1e8d31d0faf5cb47040479dfe4
```

The probe exercised representative canonical compact-patch payloads for scalar replacement/add/remove, caret-encoded JSON, escaped JSON, JSON Pointer paths and upsert/limit-related decoding behavior.

Standing for this slice: `ALIVE`.

Standing for the complete repository in this container: **`PARTIAL_ALIVE`**, because an exact source component executed but the BEAM/runtime, full dependency graph, Vitest and Playwright courts were not executable locally.

## Source-identical external verifier evidence

The fork itself has no recorded Actions runs for `6ea7b146...`, so workflow presence is not treated as execution.

However, the exact same commit SHA in the upstream repository executed on 2026-08-24 and reported successful:

- Elixir CI
- Frontend CI
- E2E Tests

This establishes **source-identical baseline verifier evidence** for the unchanged v1.2.3 subject. It is useful evidence that the admitted base is healthy under the upstream workflow environments, but it does not turn this cloud container into an executed BEAM court and it does not verify the new v26.8.27 Ash architecture, which is documentation-only at this point.

## Review findings

### 1. Best migration seam: Igniter + optional Ash

The existing installer already uses Igniter and composes PhoenixVite. The narrowest coherent first implementation is therefore to extend this installer with an optional Ash fixture/integration rather than add shell installers or runtime scanning.

### 2. Best server abstraction: Ash actions, not Phoenix-Nitro handlers

Free-floating route handlers would duplicate domain behavior. New typed server operations should bind to explicit Ash Domain/Resource/Action identities and preserve actor/tenant context.

### 3. Best route-rule implementation: Spark metadata

A Nitro-like route rules map is useful conceptually, but the BEAM-native implementation should be a validated Spark DSL with one admitted metadata representation consumed by Phoenix plugs, LiveVue SSR and later cache/prerender tooling.

### 4. Do not migrate WebSockets

Phoenix LiveView, Channels and PubSub already provide the runtime topology Nitro would otherwise have to manufacture. Adding another compatibility socket layer would be architectural regression.

### 5. Do not make Ash mandatory

LiveVue is currently broadly usable with Phoenix and optional Ecto support. Ash integration should be additive and compile-safe when absent.

### 6. Package identity/version debt

`mix.exs` identifies the release as `1.2.3`, while `package.json` currently declares `1.0.0`. Both package/repository metadata surfaces also still point to the upstream `Valian/live_vue` identity. This may be intentional for the upstream-shaped baseline, but a `26.8.27` fork release must decide and consistently manufacture its package/version/repository identity before publication.

### 7. Fork verification gap

The fork contains CI definitions but no run history for the admitted base SHA. Once implementation begins, the fork must execute exact-head CI rather than inheriting standing from upstream indefinitely.

## Recommended first implementation slice after this design PR

1. Add Ash/AshPhoenix only as optional/dev-test integration dependencies.
2. Add a Phoenix + Ash fixture application alongside the existing non-Ash courts.
3. Introduce the smallest executable `LiveVue.Ash` seam around one read/action path.
4. Adapt one form validation path through `AshPhoenix.Form` without removing `useLiveForm`'s Ecto path.
5. Prove actor and tenant propagation.
6. Refuse undeclared browser action exposure.
7. Integrate AshTypescript in the fixture so domain TypeScript is generated rather than handwritten.
8. Only after that vertical slice is ALIVE, introduce the Spark route-rule DSL, beginning with SSR policy before caching or prerendering.

## Receipt

### Changed

Documentation only on `feat/phoenix-ash-nitro-v26.8.27`:

- `docs/vision-2030.md`
- `docs/prd-ard-v26.8.27.md`
- `docs/cloud-build-audit-v26.8.27.md`

No runtime/library source has been modified in this design/audit slice.

### Executed

- toolchain and DNS orientation in cloud container;
- exact-source compact patch TypeScript compilation;
- compact patch runtime probe;
- exact-SHA upstream verifier inspection.

### Not executed locally

- `mix deps.get`
- `mix compile`
- `mix test`
- full `npm install`
- `npx tsc --noEmit` over the repository
- `npm test`
- `npm run e2e:test`
- QuickBEAM SSR court

Reason: missing BEAM toolchain plus unavailable external package/source transport in the cloud container.

### Scoped standing

- Base source identity: `ADMITTED`
- Compact patch component: `ALIVE`
- Upstream exact-SHA verifier: `VERIFIER_ALIVE` for baseline source
- Fork full cloud build: `BLOCKED:TOOLCHAIN_TRANSPORT`
- v26.8.27 design branch overall: `PARTIAL_ALIVE`
- Ash/Nitro-equivalent runtime implementation: `UNSUPPORTED` in this branch by design

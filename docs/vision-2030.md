# LiveVue Vision 2030

## Thesis

By 2030, LiveVue should make Phoenix + Ash + Vue feel like one coherent full-stack application runtime: **Vue owns rich local interaction; Phoenix owns transport, presence, realtime and deployment; Ash owns domain semantics, authorization and data access; Reactor/AshOban own workflows; LiveVue owns the typed projection boundary between them.**

The goal is not to reimplement Nuxt or Nitro in Elixir. The goal is to preserve the developer affordances that made Nuxt/Nitro effective, then remanufacture those affordances using BEAM-native semantics and Ash's introspectable application model.

## Preserve first

LiveVue 1.2.3 already contains valuable architecture that must survive the migration:

- Phoenix LiveView remains the authoritative realtime transport and server-render lifecycle.
- Vue remains the client-side local-reactivity and component ecosystem.
- LiveVue's hook lifecycle remains the Vue/LiveView bridge.
- LiveView `__changed__` tracking plus compact JSON Patch remains the incremental projection mechanism.
- LiveView streams remain first-class and must not be converted into generic client polling.
- Vite remains the development/bundling system for Vue assets.
- QuickBEAM remains the preferred production SSR mode where practical, avoiding a required Node runtime.
- Igniter remains the installation and project-mutation surface.
- Existing LiveVue public APIs remain source-compatible unless a major-version boundary explicitly changes them.

## The 2030 product

A developer should be able to define a domain once in Ash and derive all lawful application projections from it:

```text
Ash Domain / Resources / Actions / Policies
        |
        +--> Phoenix routes / LiveViews / Channels
        +--> LiveVue server projection contracts
        +--> Vue TypeScript types + RPC functions
        +--> forms + validation contracts
        +--> OpenAPI / JSON:API where desired
        +--> background workflows / scheduled actions
        +--> route/cache/SSR execution policy
        +--> telemetry + receipts
        |
        v
Vue application surfaces
```

The developer experience should approach the convenience of Nuxt/Nitro without importing Nitro's runtime assumptions into the BEAM.

## Nuxt/Nitro capability migration

| Nuxt/Nitro capability | Phoenix/Ash-native destination | 2030 rule |
| --- | --- | --- |
| server/API handlers | Phoenix Router + Ash actions + AshJsonApi/typed controllers | domain behavior lives in actions, not route files |
| filesystem server routing | Igniter-generated Phoenix routes from admitted declarations | generation is allowed; runtime magic is not required |
| `routeRules` | `LiveVue.Platform.RouteRules` Spark DSL projected to plugs/cache/SSR/headers | one policy graph, multiple runtime projections |
| runtime config | `runtime.exs` / Application env + typed LiveVue config facade | private config never enters browser payloads |
| universal storage | Ash Resources + explicit data layers | semantics first; do not recreate an untyped global KV namespace |
| handler/function cache | bounded cache behavior with ETS reference adapter and pluggable backend | cache identity includes subject/action/actor/tenant/input |
| tasks | Reactor for compositional workflows; AshOban/Oban for durable/scheduled execution | task execution has explicit authority and failure semantics |
| server plugins/hooks | Spark DSL extensions + OTP supervision + Telemetry | extensions declare capability; they do not get ambient execution authority |
| WebSockets | Phoenix Channels / LiveView / PubSub | preserve Phoenix; no compatibility wrapper needed |
| SSR | LiveView dead render + LiveVue SSR + QuickBEAM | SSR policy is declarative and route/component aware |
| prerender / hybrid rendering | build-time route projection plus LiveVue SSR policy | only deterministic/read-only routes are prerender candidates |
| payload extraction | Ash action result -> LiveView assign -> LiveVue hydration payload | never refetch data already carried by the server projection |
| OpenAPI | AshJsonApi/OpenApiSpex | generated from domain/action declarations |
| typed frontend client | AshTypescript-generated types/RPC plus LiveVue adapters | Elixir domain types remain canonical |
| deployment presets | Mix releases + deployment packs/adapters | deployment portability is manufactured outside domain logic |
| dev HMR | Phoenix code reloader + Vite HMR + LiveVue bridge | preserve the current two-runtime development loop |

## Foundational calculus

### Objects

- `Domain`: an Ash domain and its resources/actions/policies.
- `Projection`: a Vue/LiveView-visible representation of admitted domain data.
- `RouteRule`: declarative execution policy for an HTTP/LiveView route or action projection.
- `Intent`: typed request manufactured by UI interaction.
- `Workflow`: Reactor/AshOban execution graph.
- `Receipt`: evidence that a consequential action executed against the admitted subject.

### Morphisms

```text
Domain -> Route
Domain -> TypeScript contract
Domain -> Form contract
Action result -> LiveView assign
LiveView assign -> LiveVue compact patch
Compact patch -> reactive Vue state
UI event -> typed Intent
Intent -> authorized Ash Action
Action -> Workflow (when multi-step/durable)
Execution -> Receipt
Receipt -> Replay/standing
```

### Admission

A client-visible operation is admitted only when:

1. its Ash action exists and is introspectable;
2. its arguments and result types are known;
3. its authorization/actor requirements are known;
4. its transport projection is explicitly enabled;
5. consequential execution has an explicit DO path.

### Authority

LiveVue components and browser hooks have SELECT/CONSTRUCT authority only. They may manufacture typed intents. They do not receive ambient database, filesystem, deployment, workflow or external-service authority.

Consequential execution occurs in Phoenix/Ash/Reactor/Oban boundaries and must preserve actor, tenant, action identity and result/receipt identity.

## Product principles

### 1. Ash is the application ontology

Do not make Phoenix controllers, Vue composables and REST schemas separate sources of business truth. Resource/action declarations are the canonical application contract whenever Ash is installed.

### 2. Phoenix is the runtime, not an adapter around Node

Production should not require a Node server for application behavior. Node/Vite may remain build/dev tooling. QuickBEAM may execute Vue SSR JavaScript in-process, but server-side application behavior remains BEAM-native.

### 3. Vue remains fully Vue

Do not reduce Vue to templating. The reason LiveVue exists is to preserve access to Vue's composition model, reactivity, ecosystem, transitions, visualization libraries and client-local state.

### 4. No duplicated fetch graph

When Phoenix already executed an Ash action for the current render, the Vue component should receive the result through the LiveVue projection unless an independent client fetch is intentionally requested.

### 5. Realtime by default, polling by exception

Ash notifications/pub-sub, LiveView and Channels should supply realtime updates. A Nitro-style REST fetch loop is not the default architecture.

### 6. Generated contracts are projections

Generated TypeScript, route tables, OpenAPI and manifests are replaceable projections. Developers edit Ash/Spark declarations and templates/generators, not generated output.

### 7. Escape hatches remain legal

Phoenix controllers, Ecto, raw channels, plain Vue fetches and custom plugs remain possible. The architecture should make the lawful path easier without making adjacent Elixir/Vue techniques impossible.

## 2030 capability planes

### Domain plane

Ash Resources, Domains, Actions, Policies, Calculations, Aggregates and data layers.

### Presentation plane

Phoenix LiveView, LiveVue, Vue, component discovery, shared props, streams, forms, uploads, navigation and SSR.

### Transport plane

Phoenix Router, Channels, LiveView sockets, AshJsonApi, typed RPC and optional GraphQL.

### Workflow plane

Reactor for dependency-aware sagas and compensation; AshOban/Oban for durable and scheduled execution.

### Runtime policy plane

Route rules, caching, headers, redirects, SSR/prerender policy, rate limits, tenancy and actor projection.

### Extension plane

Spark extensions, Igniter installers/generators, OTP supervisors, Telemetry handlers and ggen-manufactured packs.

### Evidence plane

Telemetry, request/action identity, execution receipts, generated-manifest hashes and replay metadata.

## What Vision 2030 explicitly excludes

- A Phoenix clone of H3/Nitro internals.
- A second untyped ORM/storage abstraction beside Ash.
- Browser-side direct database authority.
- Requiring Node in production merely to provide API/server functionality.
- Replacing Phoenix Channels with a compatibility WebSocket layer.
- Turning every Vue component into an Ash Resource.
- Hiding authorization inside route handlers when it belongs in Ash policies.
- Runtime filesystem scanning as the canonical domain model.
- Hand-maintained duplicate TypeScript domain types when AshTypescript can derive them.

## Success condition

LiveVue Vision 2030 is achieved when a Phoenix/Ash application can define a meaningful domain action once, expose it to a LiveVue application with generated TypeScript contracts, authorize it through Ash, execute it through a BEAM-native runtime, stream resulting state changes back into Vue, optionally compose durable work through Reactor/AshOban, and produce enough evidence to identify exactly what subject/action executed—without requiring a parallel Nitro server implementation.

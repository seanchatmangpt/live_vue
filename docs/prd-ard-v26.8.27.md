# LiveVue v26.8.27 PRD / ARD

Status: **design baseline**

Base subject: `seanchatmangpt/live_vue@6ea7b146d66eac54506f196cc0982229083a7755` (upstream-shaped LiveVue 1.2.3)

Target release: **26.8.27**

## Product requirement document

### Problem

LiveVue already gives Phoenix applications a high-quality Vue presentation bridge, but the application/server experience is still split across several mental models:

- Phoenix/LiveView owns server state and realtime transport.
- Vite/Vue owns rich UI development.
- Ecto-specific form conventions appear at the client boundary.
- Application actions, APIs, authorization and background work are not represented by one introspectable model.
- Developers coming from Nuxt/Nitro lose useful affordances such as typed server operations, declarative route policy, universal server configuration, generated API surfaces and task conventions.

The wrong response is to embed Nitro beside Phoenix. The required response is to reproduce the useful *developer experience* using Phoenix/Ash-native capabilities.

### User

A Phoenix developer who wants Vue-level client UX while keeping domain behavior, data access, authorization, workflows and deployment on the BEAM.

### Job to be done

> Define application behavior once in Ash, consume it naturally from LiveView/Vue, retain LiveVue's current realtime/SSR strengths, and gain the best Nitro-style server affordances without introducing a second server runtime.

### v26.8.27 objective

Establish the optional Ash integration seam and its contracts without breaking existing LiveVue applications.

v26.8.27 is the **admission release**, not the full Vision 2030 implementation. It must make future features composable by placing the correct abstraction boundaries now.

### Required capabilities

#### P0 — Preserve existing LiveVue behavior

The following must remain source-compatible and behaviorally intact:

- `<.vue>` and shortcut Vue components.
- `~VUE`/LiveVue component rendering behavior.
- LiveView prop diffing and compact patch consumption.
- LiveView stream integration.
- Vue events, LiveView events, navigation, forms and uploads.
- SSR module contract.
- Vite development SSR/HMR.
- QuickBEAM production SSR.
- Igniter installer behavior for non-Ash Phoenix apps.

#### P0 — Optional Ash boundary

Ash must be optional. Installing or compiling LiveVue must not require Ash for existing consumers.

When Ash is present, LiveVue must expose a stable integration namespace (`LiveVue.Ash`) that can host action invocation, form adaptation, generated client contracts and route policy in later releases.

#### P0 — Canonical domain action rule

Any new server operation exposed to Vue through the Ash integration must reference an Ash Domain/Resource/Action identity rather than a free-floating anonymous handler.

The browser manufactures an intent; the BEAM executes an authorized action.

#### P0 — Typed client projection

The architecture must be compatible with AshTypescript-generated contracts. LiveVue must not introduce a competing TypeScript domain schema.

v26.8.27 does not need to replace all existing composables, but the new Ash seam must permit generated TypeScript action functions to use LiveVue/Channel or HTTP transports.

#### P0 — Ash-native forms path

Define the migration path from Ecto-oriented `useLiveForm` semantics toward `AshPhoenix.Form`/Ash action validation without removing the existing Ecto path.

The user-visible contract must retain:

- server-authoritative validation;
- field errors;
- submitting/submitted state;
- parameter normalization;
- LiveView-compatible event delivery.

#### P1 — Route rule model

Define an extensible route/action rule vocabulary capable of expressing at least:

- SSR enabled/disabled;
- cache policy/max age;
- redirect;
- response headers;
- prerender eligibility;
- authentication/actor requirement;
- tenant requirement;
- rate-limit policy identifier;
- telemetry/evidence policy.

The declaration should be implemented as a Spark DSL in a later slice. v26.8.27 must reserve the module and contract shape and prove that rules project into Phoenix/Ash rather than execute independently.

#### P1 — Task/workflow mapping

Document and reserve the integration boundary:

- Reactor for dependency-aware, compensatable multi-step workflows.
- AshOban/Oban for durable/background/scheduled execution.

LiveVue itself must not become a job runner.

#### P1 — Runtime configuration

Define a typed LiveVue configuration facade over standard Elixir runtime configuration. Server-private values must never be serialized to Vue unless explicitly projected as public configuration.

### Non-goals for v26.8.27

- Replacing Phoenix Router with filesystem routing.
- Reimplementing Nitro's `unstorage` API.
- Shipping a general cache framework.
- Replacing LiveView/Channels/PubSub.
- Moving application logic into JavaScript SSR.
- Requiring PostgreSQL, AshPostgres or Oban for all LiveVue consumers.
- Making Ash a hard dependency.
- Automatically exposing every Ash action to the browser.
- Implementing cloud deployment presets in this package.

### Product interfaces

#### Existing consumer — unchanged

```elixir
<.vue v-component="Counter" count={@count} />
```

#### Future Ash-aware LiveView invocation

Conceptual API:

```elixir
LiveVue.Ash.run(
  MyApp.Accounts,
  MyApp.Accounts.User,
  :change_email,
  %{email: params["email"]},
  actor: socket.assigns.current_user,
  tenant: socket.assigns.current_tenant
)
```

This is illustrative. The final implementation should prefer Ash code interfaces when available rather than make users spell resource internals repeatedly.

#### Future generated TypeScript invocation

```ts
const result = await changeEmail({ email })
```

The function is generated from AshTypescript; LiveVue supplies/adapts transport and realtime projection, not the schema.

### Acceptance criteria

v26.8.27 is accepted only when:

1. existing Elixir unit tests pass;
2. existing TypeScript/Vitest tests pass;
3. existing Playwright E2E tests pass;
4. an example Phoenix app without Ash still installs and runs;
5. an example Phoenix + Ash app can install the optional integration without duplicate domain types;
6. SSR still works through ViteJS in development and QuickBEAM in production court;
7. no browser-facing Ash action is exposed without an explicit declaration;
8. all new optional Ash references are compile-safe when Ash is absent;
9. generated/client-facing contracts have an exact source identity;
10. no consequential UI path obtains ambient DO authority.

## Architecture requirement document

### Current architecture observed at the base SHA

The current library already contains the following relevant layers:

```text
Phoenix LiveView render
  -> LiveVue.vue/1
     -> LiveView __changed__ / streams
     -> Encoder
     -> Jsonpatch / compact Patch
     -> HEEX wrapper data attributes
     -> optional SSR
        -> ViteJS (development)
        -> NodeJS (production option)
        -> QuickBEAM (production default/recommended)

Browser
  -> VueHook
  -> Vue reactive props/slots
  -> compact patch decode/apply
  -> useLiveVue/useLiveForm/useLiveUpload/navigation
  -> LiveView socket
```

The installer is already Igniter-based and composes the PhoenixVite installer, Vue/Vite configuration, QuickBEAM production SSR and project code modification. This is the correct extension seam for Ash installation.

### Target architecture

```text
                        +---------------------------+
                        |   Ash Domain / Resources  |
                        | Actions / Policies / Types|
                        +-------------+-------------+
                                      |
                          introspection/admission
                                      |
               +----------------------+----------------------+
               |                                             |
       +-------v--------+                            +-------v--------+
       | Phoenix/LiveView|                            | API projection |
       | Channels/PubSub |                            | AshJsonApi etc.|
       +-------+--------+                            +----------------+
               |
       action result / notification
               |
       +-------v-----------------------------------------------+
       |                    LiveVue                           |
       | SSR policy | projection | compact patches | intents |
       +-------+-----------------------------------------------+
               |
       +-------v--------+
       | Vue runtime    |
       | generated types|
       | local state    |
       +----------------+

Consequential multi-step action
  -> Reactor
  -> AshOban/Oban when durable/scheduled
  -> result/notification/receipt
```

### Dependency strategy

Current LiveVue dependencies remain canonical.

New Ash ecosystem dependencies must be optional or development/test-only until a specific integration requires them.

Candidate dependencies:

```elixir
{:ash, "~> 3.0", optional: true}
{:ash_phoenix, "~> 2.0", optional: true}
```

AshTypescript, AshJsonApi, Reactor and AshOban should **not** automatically become hard runtime dependencies of LiveVue. They are ecosystem projection/workflow integrations and should be detected/configured by Igniter when selected by the consumer.

Version ranges above are architectural placeholders until verified against the implementation toolchain at coding time.

### Namespace plan

```text
LiveVue.Ash
LiveVue.Ash.Form
LiveVue.Ash.Transport
LiveVue.Ash.Intent
LiveVue.Platform.RouteRule
LiveVue.Platform.RouteRules
LiveVue.Platform.Cache
LiveVue.Platform.Config
LiveVue.Platform.Receipt
```

Do not create all modules merely to satisfy this document. A namespace is admitted when its first executable consumer exists.

### SELECT / CONSTRUCT / DO

#### SELECT

- choose action;
- choose fields;
- navigate;
- choose component;
- choose workflow input.

#### CONSTRUCT

- construct Ash action input;
- construct form params;
- construct route/action policy;
- construct background-work request;
- construct a typed intent.

#### DO

Only server-side authorized execution may perform consequential operations.

A Vue event or hook never directly becomes a database/external-service mutation. It becomes a typed intent, which resolves to an explicitly exposed Ash action (or existing Phoenix event) under actor/tenant authorization.

### Route rules architecture

Do not clone Nitro `routeRules` as a map interpreted ad hoc at request time.

Preferred design:

```elixir
defmodule MyAppWeb.LiveVuePolicy do
  use LiveVue.Platform.RouteRules

  route "/public/**" do
    ssr true
    cache max_age: 60
  end

  route "/account/**" do
    actor :required
    cache false
    prerender false
  end
end
```

A Spark transformer/verifier should convert rules into validated immutable metadata. Phoenix plugs, LiveVue SSR, cache adapters and build-time prerender tooling consume that metadata.

Falsifier: if two consumers independently parse the DSL into different meanings, the design has failed. There must be one admitted rule model.

### Caching architecture

Caching must be action-aware and authorization-safe.

A cache key for an Ash result must be able to include:

```text
resource/action identity
input fingerprint
actor identity or visibility partition
 tenant
field/load selection
code/config version
```

Anonymous global caching of authorized Ash records is REFUSED.

v26.8.27 should not ship caching until this identity model is enforced.

### Storage architecture

Nitro's universal KV storage is useful as a portability affordance but is a poor canonical domain abstraction for Ash applications.

Rules:

- domain state -> Ash Resource/DataLayer;
- ephemeral local cache -> explicit cache adapter/ETS;
- files/blobs -> dedicated storage adapter/resource;
- session/socket state -> Phoenix/Plug/LiveView mechanisms;
- no `useStorage("anything")` equivalent with ambient write authority.

### Task/workflow architecture

One-off or multi-step application logic should first be an Ash action.

Use Reactor when execution has a dependency graph, parallel steps, compensation or undo semantics.

Use AshOban/Oban when work must survive process/node restarts, execute later or run on a schedule.

A UI-triggered workflow follows:

```text
Vue event
 -> LiveView/typed RPC
 -> admitted Ash action/intent
 -> Reactor or durable job if needed
 -> domain mutation
 -> PubSub/notification
 -> LiveView
 -> LiveVue patch
 -> Vue
```

### SSR architecture

Preserve the existing `LiveVue.SSR` behavior contract.

Route policy may choose whether SSR is used, but rendering continues through the configured SSR module.

Production preference remains QuickBEAM where the Vue SSR bundle is compatible. NodeJS remains a compatibility option, not the application server.

### TypeScript architecture

Canonical types originate from Ash when the Ash integration is used.

AshTypescript may generate:

- resource/action types;
- RPC calls;
- Zod validation;
- channel transport functions.

LiveVue TypeScript continues to own presentation-specific contracts:

- LiveVue hook/plugin types;
- compact patch operations;
- LiveView transport integration;
- component lifecycle context;
- upload/navigation helpers.

The two sets of types meet at an adapter; they do not duplicate each other.

### Installation architecture

Extend the existing Igniter task rather than introduce a separate shell installer.

Desired eventual flows:

```bash
mix live_vue.install
mix live_vue.install --ash
mix live_vue.install --ash --typescript
mix live_vue.install --ash --json-api
```

Flags are illustrative until implemented. Each option must detect existing dependencies/configuration and converge idempotently.

### Testing architecture

#### Existing courts

- `mix test`
- `npm test`
- `npx tsc --noEmit`
- `npm run e2e:test`

#### New v26.8.27 courts

- compile with Ash absent;
- compile with Ash present;
- installer idempotence for plain Phoenix;
- installer idempotence for Phoenix + Ash;
- Ash form validation projection;
- action exposure refusal test;
- actor/tenant propagation test;
- generated TypeScript compatibility fixture;
- route-rule verifier tests once DSL exists.

### Migration sequence

1. **Fence and characterize** current LiveVue behavior with exact baseline tests.
2. Add optional Ash compile/test fixture without changing default runtime.
3. Introduce `LiveVue.Ash` minimal executable seam.
4. Adapt one form/action vertical slice end-to-end.
5. Integrate AshTypescript in a fixture; generated code remains projection-only.
6. Add explicit action exposure/admission model.
7. Introduce Spark route-rule model with SSR-only policy first.
8. Extend route policy to cache/headers/redirect/prerender after identity rules are proven.
9. Add Reactor/AshOban example vertical slices; do not put workflow execution in LiveVue core.
10. Expand deployment/manufacturing integrations outside the domain/runtime core.

### Release standing ladder

- `UNKNOWN`: source inspected only.
- `PARTIAL_ALIVE`: at least one exact executable slice has run, but full baseline court has not.
- `ALIVE`: exact release subject passes Elixir, frontend and E2E baseline plus new Ash fixture acceptance.
- `BLOCKED`: required external toolchain/transport unavailable; source failure not demonstrated.
- `BUILD_BROKEN`: admitted toolchain executes and project build/test fails.
- `UNSUPPORTED`: requested capability has no implementation contract.
- typed `REFUSED`: architecture explicitly denies an unsafe or ambiguous operation.

### Release falsifier

v26.8.27 must be rejected if adding Ash:

- breaks plain Phoenix consumers;
- turns Ash into a mandatory dependency;
- duplicates Ash domain types manually in TypeScript;
- bypasses Ash policies for convenience;
- requires Node as the application server;
- replaces LiveView realtime with polling;
- causes route policy to become an independent authorization system;
- or weakens the current LiveVue SSR/diff/stream behavior to gain the new architecture.

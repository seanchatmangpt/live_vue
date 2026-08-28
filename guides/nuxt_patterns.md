# Nuxt-style patterns in LiveVue

LiveVue adopts the useful **developer patterns** from Nuxt while keeping Phoenix,
LiveView and the BEAM as the authoritative server runtime. This is deliberately
not a Nitro compatibility layer.

The preservation fence is simple:

- Phoenix owns HTTP routing and request authority.
- LiveView owns realtime state and navigation.
- Vue owns client rendering and reactivity.
- LiveVue owns the bridge, request-scoped client helpers and typed operation seam.
- Ash, Reactor and other server runtimes remain optional, consumer-owned adapters.
- A client descriptor, middleware result or payload never grants server execution authority.

## Capability map

| Nuxt pattern | LiveVue equivalent | Authority boundary |
| --- | --- | --- |
| `useState` | `useLiveState` | scoped to one Vue app/request |
| `useAsyncData` | `useLiveAsyncData` | keyed client cache; no server authority |
| `useFetch` | `useLiveFetch` | injected/default HTTP transport |
| `runtimeConfig.public` | `useLiveRuntimeConfig` | explicitly supplied public values only |
| Nuxt plugins | `defineLiveVuePlugin` + `plugins:` | normal Vue plugin composition |
| layouts | `useLiveLayout` + `LiveVueLayout` | app-scoped component registry |
| route middleware | `defineLiveRouteMiddleware` + `runLiveRouteMiddleware` | returns intent; Phoenix/LiveView actuates navigation |
| `useHead` | `useLiveHead` | reconciles only LiveVue-owned head elements |
| app error state | `useLiveError` + `LiveVueErrorBoundary` | app-local rendering state |
| `callOnce` | `callLiveOnce` | once per app/request key; retry after failure |
| SSR payload | `dehydrateLivePayload` / `hydrateLivePayload` | JSON-safe state projection |
| route rules | `LiveVue.RouteRules` | Phoenix Plug metadata, not a second router |
| typed server operations | `defineLiveServerOperation` + `LiveVue.ServerOperation` | explicit registry + consumer executor + receipts |

## Install the app-scoped patterns plugin

```ts
import {
  createLiveVue,
  createNuxtPatternsPlugin,
} from "live_vue"

const liveVue = createLiveVue({
  resolve: (name) => pages[`./${name}.vue`],
  plugins: [
    createNuxtPatternsPlugin({
      runtimeConfig: {
        apiBase: "/api",
        publicSiteUrl: "https://example.com",
      },
    }),
  ],
})
```

The plugin stores state, async cache entries, once-results, layout selection,
head state and errors on the Vue application instance. It does not use a
module-global request cache, which prevents accidental SSR state sharing.

## Request-safe shared state

```ts
import { useLiveState } from "live_vue"

const selectedTeam = useLiveState("selected-team", () => "engineering")
```

The same key in the same Vue application returns the same `Ref`. The same key
in a different app/request is isolated.

## Async data and fetch

```ts
import { useLiveAsyncData, useLiveFetch } from "live_vue"

const profile = useLiveAsyncData(
  `profile:${userId}`,
  async ({ signal }) => loadProfile(userId, signal),
)

const activity = useLiveFetch<Activity[]>("/api/activity")
```

`useLiveAsyncData` provides keyed deduplication, `idle | pending | success |
error` status, abortable refresh and deterministic clear behavior. Hydrated
payload data starts at `success` and suppresses the duplicate immediate client
request.

`useLiveFetch` is intentionally a thin transport projection over async data.
Applications may inject a fetch implementation to centralize Phoenix endpoint,
authentication and observability policy.

## Public runtime configuration

```ts
import { useLiveRuntimeConfig } from "live_vue"

const config = useLiveRuntimeConfig<{ apiBase: string }>()
```

Only values explicitly supplied to `createNuxtPatternsPlugin({ runtimeConfig })`
exist in this client projection. Secret BEAM runtime configuration is not
implicitly copied into the browser.

## Layouts

```ts
import DefaultLayout from "./layouts/DefaultLayout.vue"
import AdminLayout from "./layouts/AdminLayout.vue"
import {
  createNuxtPatternsPlugin,
  useLiveLayout,
  LiveVueLayout,
} from "live_vue"

const plugin = createNuxtPatternsPlugin({
  layouts: {
    default: DefaultLayout,
    admin: AdminLayout,
  },
  defaultLayout: "default",
})

const layout = useLiveLayout()
layout.set("admin")
```

`LiveVueLayout` renders the selected registered component around its default
slot. Unknown layout names fail fast instead of silently resolving arbitrary
components.

## Route middleware without a second router

```ts
import {
  defineLiveRouteMiddleware,
  runLiveRouteMiddleware,
} from "live_vue"

const requireAuth = defineLiveRouteMiddleware((to) => {
  if (to.meta?.authenticated) return true
  return { redirect: "/login", replace: true }
})
```

Register named middleware on the plugin:

```ts
createNuxtPatternsPlugin({
  routeMiddleware: {
    auth: requireAuth,
  },
})
```

Then evaluate it against an exact route subject:

```ts
const intent = await runLiveRouteMiddleware("auth", {
  path: "/admin",
  meta: { authenticated: false },
})
```

The return value is **navigation intent only**. `runLiveRouteMiddleware` does not
call `history`, Phoenix or LiveView navigation APIs. The application decides how
to actuate an admitted redirect or abort through its existing router/navigation
boundary.

## Head and SEO metadata

```ts
import { useLiveHead } from "live_vue"

useLiveHead({
  title: "Dashboard",
  meta: [
    { name: "description", content: "Account dashboard" },
    { property: "og:title", content: "Dashboard" },
  ],
  link: [
    { rel: "canonical", href: "https://example.com/dashboard" },
  ],
})
```

Client reconciliation tags its own elements with `data-live-vue-head` and only
replaces those elements. Head tags owned by Phoenix, LiveView or another library
are preserved.

## Error state and boundaries

```ts
import {
  LiveVueErrorBoundary,
  showLiveError,
  clearLiveError,
  useLiveError,
} from "live_vue"
```

`LiveVueErrorBoundary` captures descendant Vue render errors into app-local error
state. `showLiveError` and `clearLiveError` provide explicit programmatic control.
This is rendering/error state; it does not reinterpret Phoenix HTTP or LiveView
process failures as client authority.

## `callOnce`

```ts
import { callLiveOnce } from "live_vue"

const capabilities = await callLiveOnce("capabilities", () => loadCapabilities())
```

Concurrent calls with the same key share one promise. A successful value is
remembered for the app/request. A failed call removes the pending entry so a
later call may retry rather than permanently caching failure.

## SSR payload dehydration and hydration

```ts
import {
  dehydrateLivePayload,
  serializeLivePayload,
  hydrateLivePayload,
} from "live_vue"
```

The payload contains only JSON-safe LiveVue projection state:

```ts
{
  version: 1,
  state: {},
  asyncData: {},
  once: {},
  layout: "default",
  head: {},
}
```

`serializeLivePayload` escapes `<` and JavaScript line-separator characters for
safe embedding in HTML. Error objects, executors and execution authority are not
serialized. A hydrated async-data key is reused instead of immediately refetched.

## Phoenix-native route rules

LiveVue route rules provide Nuxt-like route metadata without adding another
router:

```elixir
rules = [
  LiveVue.RouteRules.new!("/blog/**", cache: 60),
  LiveVue.RouteRules.new!("/admin/**", ssr: false, headers: %{
    "x-frame-options" => "DENY"
  })
]

plug LiveVue.RouteRules.Plug, rules: rules
```

Phoenix still performs route matching and dispatch. The LiveVue plug selects the
most-specific matching rule, stores it in `conn.private`, applies response-safe
headers/cache policy and exposes SSR policy through `LiveVue.RouteRules.ssr?/2`.

## Typed Phoenix and Ash operations

### Client descriptor

A typed descriptor binds client code to a stable exact operation identity:

```ts
import {
  defineLiveServerOperation,
  callLiveServerOperation,
} from "live_vue"

type CreatePost = { title: string }
type Post = { id: string; title: string }

const createPost = defineLiveServerOperation<CreatePost, Post>({
  id: "posts.create",
  subject: "Post@v1",
  backend: {
    kind: "ash",
    domain: "Blog",
    resource: "Post",
    action: "create",
  },
  consequential: true,
})

const { data, receipt } = await callLiveServerOperation(
  createPost,
  { title: "Hello" },
  { correlationId: crypto.randomUUID() },
)
```

The descriptor supplies identity and compile-time input/output correspondence.
It is **not** an execution token.

Applications can inject a `serverOperationTransport` or use the default receipted
HTTP POST projection. The default client refuses a response that omits its
receipt.

### Server descriptor and admission

The server separately declares what is exposed:

```elixir
create_post =
  LiveVue.ServerOperation.new!("posts.create", "Post@v1",
    backend: :ash,
    domain: "Blog",
    resource: "Post",
    action: "create",
    consequential: true,
    requires_actor: true,
    requires_tenant: true
  )
```

The server registry, not the client descriptor, is the exposure boundary. An
unknown operation ID is refused before the executor runs.

When `requires_actor` or `requires_tenant` is enabled, those identities must be
present in server-owned context before execution. The HTTP body cannot manufacture
either identity. A Phoenix plug or application adapter can derive them from the
session, authenticated principal, tenant host, Ash context or another admitted
server source.

### Consumer-owned executor

```elixir
defmodule MyApp.LiveVueExecutor do
  @behaviour LiveVue.ServerOperation.Executor

  @impl true
  def run(operation, input, context) do
    # The application maps the admitted descriptor to Phoenix/Ash/Reactor here.
    # LiveVue does not add a mandatory Ash dependency.
    MyApp.Operations.run(operation, input, context)
  end
end
```

The generic HTTP projection can then be mounted with an explicit registry and
server context manufacturer:

```elixir
plug LiveVue.ServerOperation.Plug,
  operations: [create_post],
  executor: MyApp.LiveVueExecutor,
  context: fn conn ->
    %{
      actor: conn.assigns.current_user,
      tenant: conn.assigns.current_tenant,
      correlation_id: List.first(Plug.Conn.get_req_header(conn, "x-request-id"))
    }
  end
```

Every executor attempt receives a deterministic outcome receipt binding operation
ID, exact subject, backend identity, input, actor identity, tenant identity,
correlation identity and outcome. Actor and tenant values affect the digest but
are deliberately not echoed in the public receipt projection.

## Why there is no Nitro server in LiveVue

Nitro solves server/runtime problems that Phoenix and the BEAM already solve:
HTTP dispatch, long-lived processes, supervision, realtime messaging, runtime
configuration and production execution. Reimplementing that runtime in
JavaScript would create two server authorities.

LiveVue therefore migrates the high-value **affordances** while preserving a
single server topology:

```text
Vue component
  -> LiveVue composable / typed intent
  -> Phoenix / LiveView admission
  -> optional consumer runtime (Ash/Reactor/application service)
  -> outcome + receipt
  -> LiveVue/Vue projection
```

That correspondence is the compatibility target. Runtime duplication is not.

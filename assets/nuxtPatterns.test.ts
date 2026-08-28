import { createApp, defineComponent, h, nextTick } from "vue"
import { afterEach, describe, expect, it, vi } from "vitest"
import {
  callLiveOnce,
  callLiveServerOperation,
  createNuxtPatternsPlugin,
  defineLiveRouteMiddleware,
  defineLiveServerOperation,
  hydrateLivePayload,
  runLiveRouteMiddleware,
  serializeLivePayload,
  useLiveAsyncData,
  useLiveError,
  useLiveFetch,
  useLiveHead,
  useLiveLayout,
  useLiveRuntimeConfig,
  useLiveState,
  type LiveServerOperationResponse,
} from "./nuxtPatterns.js"

const mounted: ReturnType<typeof createApp>[] = []

afterEach(() => {
  for (const app of mounted.splice(0)) app.unmount()
  document.body.innerHTML = ""
  document.title = ""
  for (const element of Array.from(document.head.querySelectorAll("[data-live-vue-head]"))) element.remove()
})

const mountSetup = <T>(setup: () => T, plugin = createNuxtPatternsPlugin()) => {
  let exposed!: T
  const target = document.createElement("div")
  document.body.appendChild(target)

  const app = createApp(
    defineComponent({
      setup() {
        exposed = setup()
        return () => h("div")
      },
    })
  )
  app.use(plugin)
  app.mount(target)
  mounted.push(app)
  return exposed
}

describe("Nuxt-style LiveVue patterns", () => {
  it("shares keyed state inside one app without module-global state", () => {
    const values = mountSetup(() => {
      const first = useLiveState("counter", () => 1)
      const second = useLiveState("counter", () => 999)
      return { first, second }
    })

    expect(values.first).toBe(values.second)
    expect(values.first.value).toBe(1)
    values.second.value = 2
    expect(values.first.value).toBe(2)
  })

  it("isolates the same state key between app instances", () => {
    const first = mountSetup(() => useLiveState("request", () => "first"))
    const second = mountSetup(() => useLiveState("request", () => "second"))

    expect(first.value).toBe("first")
    expect(second.value).toBe("second")
  })

  it("deduplicates async work by key and exposes reactive status", async () => {
    const handler = vi.fn(async () => ({ id: 7 }))
    const values = mountSetup(() => {
      const first = useLiveAsyncData("post:7", handler, { immediate: false })
      const second = useLiveAsyncData("post:7", handler, { immediate: false })
      return { first, second }
    })

    expect(values.first).toBe(values.second)
    const [left, right] = await Promise.all([values.first.refresh(), values.second.refresh()])
    await nextTick()

    expect(handler).toHaveBeenCalledTimes(1)
    expect(left).toEqual({ id: 7 })
    expect(right).toEqual({ id: 7 })
    expect(values.first.status.value).toBe("success")
    expect(values.first.data.value).toEqual({ id: 7 })
  })

  it("clears keyed async state deterministically", async () => {
    const value = mountSetup(() => useLiveAsyncData("clearable", async () => "done", { immediate: false }))
    await value.refresh()
    value.clear()

    expect(value.status.value).toBe("idle")
    expect(value.data.value).toBeUndefined()
    expect(value.error.value).toBeUndefined()
  })

  it("hydrates async payloads without duplicate client fetch", () => {
    const handler = vi.fn(async () => ({ id: 8 }))
    const value = mountSetup(
      () => useLiveAsyncData("post:8", handler),
      createNuxtPatternsPlugin({
        initialPayload: {
          version: 1,
          state: {},
          asyncData: { "post:8": { id: 8 } },
          once: {},
        },
      })
    )

    expect(handler).not.toHaveBeenCalled()
    expect(value.status.value).toBe("success")
    expect(value.data.value).toEqual({ id: 8 })
  })

  it("uses an injected fetch transport and deduplicates identical requests", async () => {
    const fetcher = vi.fn(async () => ({
      ok: true,
      status: 200,
      statusText: "OK",
      json: async () => ({ source: "phoenix" }),
      text: async () => "phoenix",
    })) as unknown as typeof globalThis.fetch

    const values = mountSetup(
      () => {
        const first = useLiveFetch<{ source: string }>("/api/profile", { immediate: false })
        const second = useLiveFetch<{ source: string }>("/api/profile", { immediate: false })
        return { first, second }
      },
      createNuxtPatternsPlugin({ fetch: fetcher })
    )

    await Promise.all([values.first.refresh(), values.second.refresh()])
    expect(fetcher).toHaveBeenCalledTimes(1)
    expect(values.first.data.value).toEqual({ source: "phoenix" })
  })

  it("exposes only explicitly supplied public runtime configuration", () => {
    const config = mountSetup(
      () => useLiveRuntimeConfig<{ apiBase: string }>(),
      createNuxtPatternsPlugin({ runtimeConfig: { apiBase: "/api" } })
    )

    expect(config.apiBase).toBe("/api")
    expect(Object.keys(config)).toEqual(["apiBase"])
  })

  it("selects only registered layouts", () => {
    const DefaultLayout = defineComponent({ name: "DefaultLayout", setup: () => () => h("main") })
    const AdminLayout = defineComponent({ name: "AdminLayout", setup: () => () => h("aside") })

    const layout = mountSetup(
      () => useLiveLayout(),
      createNuxtPatternsPlugin({ layouts: { default: DefaultLayout, admin: AdminLayout } })
    )

    expect(layout.name.value).toBe("default")
    expect(layout.resolve()).toBe(DefaultLayout)
    layout.set("admin")
    expect(layout.name.value).toBe("admin")
    expect(layout.resolve()).toBe(AdminLayout)
    expect(() => layout.set("missing")).toThrow("Unknown LiveVue layout")
  })

  it("runs named route middleware in order and returns redirect intent without navigating", async () => {
    const audit = vi.fn(defineLiveRouteMiddleware(() => true))
    const auth = vi.fn(
      defineLiveRouteMiddleware((to) => (to.meta?.authenticated ? true : { redirect: "/login", replace: true }))
    )

    const result = mountSetup(
      () => runLiveRouteMiddleware(["audit", "auth"], { path: "/admin", meta: { authenticated: false } }),
      createNuxtPatternsPlugin({ routeMiddleware: { audit, auth } })
    )

    await expect(result).resolves.toEqual({ redirect: "/login", replace: true })
    expect(audit).toHaveBeenCalledTimes(1)
    expect(auth).toHaveBeenCalledTimes(1)
  })

  it("refuses unknown route middleware and relative route subjects", async () => {
    const unknown = mountSetup(() => runLiveRouteMiddleware("missing", { path: "/safe" }))
    await expect(unknown).rejects.toThrow("Unknown LiveVue route middleware")

    const relative = mountSetup(
      () => runLiveRouteMiddleware("known", { path: "relative" }),
      createNuxtPatternsPlugin({ routeMiddleware: { known: () => true } })
    )
    await expect(relative).rejects.toThrow("absolute route path")
  })

  it("reconciles title, SEO metadata and links without deleting foreign head tags", () => {
    const foreign = document.createElement("meta")
    foreign.setAttribute("name", "foreign")
    foreign.setAttribute("content", "preserve")
    document.head.appendChild(foreign)

    mountSetup(() =>
      useLiveHead({
        title: "LiveVue dashboard",
        meta: [
          { name: "description", content: "Phoenix and Vue" },
          { property: "og:title", content: "LiveVue dashboard" },
        ],
        link: [{ rel: "canonical", href: "https://example.test/dashboard" }],
      })
    )

    expect(document.title).toBe("LiveVue dashboard")
    expect(document.head.querySelector('meta[name="description"]')?.getAttribute("content")).toBe("Phoenix and Vue")
    expect(document.head.querySelector('meta[property="og:title"]')?.getAttribute("content")).toBe("LiveVue dashboard")
    expect(document.head.querySelector('link[rel="canonical"]')?.getAttribute("href")).toBe(
      "https://example.test/dashboard"
    )
    expect(document.head.contains(foreign)).toBe(true)
  })

  it("stores and clears normalized application errors", () => {
    const errors = mountSetup(() => useLiveError())
    const shown = errors.show(new Error("boom"))

    expect(shown.message).toBe("boom")
    expect(errors.error.value?.message).toBe("boom")
    errors.clear()
    expect(errors.error.value).toBeUndefined()
  })

  it("runs callOnce work exactly once per app key", async () => {
    const factory = vi.fn(async () => ({ configured: true }))
    const values = mountSetup(() => ({
      first: callLiveOnce("bootstrap", factory),
      second: callLiveOnce("bootstrap", factory),
    }))

    await expect(Promise.all([values.first, values.second])).resolves.toEqual([
      { configured: true },
      { configured: true },
    ])
    expect(factory).toHaveBeenCalledTimes(1)
  })

  it("allows callOnce retry after a failed attempt", async () => {
    const factory = vi.fn().mockRejectedValueOnce(new Error("first failure")).mockResolvedValueOnce("ok")
    const first = mountSetup(() => callLiveOnce("retryable", factory))
    await expect(first).rejects.toThrow("first failure")

    const second = mountSetup(() => callLiveOnce("retryable", factory))
    await expect(second).resolves.toBe("ok")
    expect(factory).toHaveBeenCalledTimes(2)
  })

  it("hydrates state and serializes an HTML-safe payload", () => {
    const payload = {
      version: 1 as const,
      state: { greeting: "hello" },
      asyncData: {},
      once: {},
      layout: "default",
      head: { title: "<unsafe>" },
    }

    const values = mountSetup(() => {
      hydrateLivePayload(payload)
      const greeting = useLiveState<string>("greeting")
      return { greeting, serialized: serializeLivePayload() }
    })

    expect(values.greeting.value).toBe("hello")
    expect(values.serialized).toContain("\\u003cunsafe>")
    expect(values.serialized).not.toContain("<unsafe>")
  })

  it("executes typed Ash operations only through the configured transport", async () => {
    type Input = { title: string }
    type Output = { id: string; title: string }

    const operation = defineLiveServerOperation<Input, Output>({
      id: "posts.create",
      subject: "Post@v1",
      backend: { kind: "ash", domain: "Blog", resource: "Post", action: "create" },
      consequential: true,
    })

    const transport = vi.fn(async (_operation, input) => ({
      data: { id: "post-1", ...(input as Input) },
      receipt: {
        digest: "abc",
        operation_id: "posts.create",
        subject: "Post@v1",
        correlation_id: "req-1",
        status: "ok" as const,
        executed: true,
      },
    }))

    const result = mountSetup(
      () => callLiveServerOperation(operation, { title: "Hello" }, { correlationId: "req-1" }),
      createNuxtPatternsPlugin({ serverOperationTransport: transport })
    )

    await expect(result).resolves.toEqual({
      data: { id: "post-1", title: "Hello" },
      receipt: expect.objectContaining({ operation_id: "posts.create", executed: true }),
    } satisfies LiveServerOperationResponse<Output>)
    expect(transport).toHaveBeenCalledTimes(1)
    expect(transport.mock.calls[0][0]).toEqual(operation)
  })

  it("uses the default receipted Phoenix HTTP seam when no operation transport is injected", async () => {
    const operation = defineLiveServerOperation<{ id: number }, { ok: boolean }>({
      id: "profile.refresh",
      subject: "Profile@v2",
      backend: { kind: "phoenix", handler: "ProfileController.refresh" },
    })

    const fetcher = vi.fn(async (_url, request) => ({
      ok: true,
      status: 200,
      statusText: "OK",
      json: async () => ({
        data: { ok: true },
        receipt: {
          digest: "receipt",
          operation_id: "profile.refresh",
          subject: "Profile@v2",
          status: "ok",
          executed: true,
        },
      }),
      text: async () => "",
      request,
    })) as unknown as typeof globalThis.fetch

    const result = mountSetup(
      () => callLiveServerOperation(operation, { id: 7 }),
      createNuxtPatternsPlugin({ fetch: fetcher, serverOperationEndpoint: "/ops" })
    )

    await expect(result).resolves.toEqual({
      data: { ok: true },
      receipt: expect.objectContaining({ digest: "receipt" }),
    })
    expect(fetcher).toHaveBeenCalledTimes(1)
    expect(fetcher.mock.calls[0][0]).toBe("/ops/profile.refresh")
    expect(JSON.parse(String(fetcher.mock.calls[0][1]?.body))).toMatchObject({
      operation: { id: "profile.refresh", subject: "Profile@v2" },
      input: { id: 7 },
    })
  })

  it("fails fast when composables run without the app plugin", () => {
    expect(() => mountSetup(() => useLiveState("missing"), { install() {} })).toThrow(
      "createNuxtPatternsPlugin()"
    )
  })
})

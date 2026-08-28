import { createApp, defineComponent, h, nextTick, type Ref } from "vue"
import { afterEach, describe, expect, it, vi } from "vitest"
import {
  createNuxtPatternsPlugin,
  useLiveAsyncData,
  useLiveFetch,
  useLiveRuntimeConfig,
  useLiveState,
  type LiveAsyncData,
} from "./nuxtPatterns.js"

const mounted: ReturnType<typeof createApp>[] = []

afterEach(() => {
  for (const app of mounted.splice(0)) app.unmount()
  document.body.innerHTML = ""
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

  it("fails fast when composables run without the app plugin", () => {
    expect(() => mountSetup(() => useLiveState("missing"), { install() {} })).toThrow(
      "createNuxtPatternsPlugin()"
    )
  })
})

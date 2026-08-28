import {
  computed,
  inject,
  readonly,
  ref,
  shallowRef,
  type App,
  type Plugin,
  type Ref,
  type ShallowRef,
} from "vue"

export type LiveRuntimeConfig = Readonly<Record<string, unknown>>
export type LiveAsyncStatus = "idle" | "pending" | "success" | "error"
export type LiveAsyncHandler<T> = (context: { signal: AbortSignal }) => Promise<T>

export type LiveAsyncData<T> = {
  data: ShallowRef<T | undefined>
  error: ShallowRef<unknown | undefined>
  status: Ref<LiveAsyncStatus>
  pending: Readonly<Ref<boolean>>
  refresh: () => Promise<T | undefined>
  clear: () => void
}

export type LiveFetchOptions = RequestInit & {
  key?: string
  immediate?: boolean
  parse?: "json" | "text"
}

export type NuxtPatternOptions = {
  runtimeConfig?: Record<string, unknown>
  fetch?: typeof globalThis.fetch
}

type AsyncEntry<T> = LiveAsyncData<T> & {
  controller?: AbortController
  promise?: Promise<T | undefined>
}

type NuxtPatternContext = {
  state: Map<string, Ref<unknown>>
  asyncData: Map<string, AsyncEntry<unknown>>
  runtimeConfig: LiveRuntimeConfig
  fetch?: typeof globalThis.fetch
}

const contextKey = Symbol("LiveVueNuxtPatterns")

const currentContext = (): NuxtPatternContext => {
  const context = inject<NuxtPatternContext | undefined>(contextKey, undefined)
  if (!context) throw new Error("Nuxt-style LiveVue composables require createNuxtPatternsPlugin()")
  return context
}

/**
 * Creates a per-Vue-app context inspired by Nuxt's request-scoped app state.
 * State and async caches live on the Vue app instance, never in module globals,
 * so SSR applications do not accidentally share state between requests.
 */
export const createNuxtPatternsPlugin = (options: NuxtPatternOptions = {}): Plugin => ({
  install(app: App) {
    const context: NuxtPatternContext = {
      state: new Map(),
      asyncData: new Map(),
      runtimeConfig: Object.freeze({ ...(options.runtimeConfig || {}) }),
      fetch: options.fetch,
    }
    app.provide(contextKey, context)
  },
})

/** Nuxt useState pattern, scoped to one LiveVue application instance. */
export const useLiveState = <T>(key: string, init?: () => T): Ref<T> => {
  if (!key) throw new Error("useLiveState requires a non-empty key")
  const context = currentContext()
  const existing = context.state.get(key)
  if (existing) return existing as Ref<T>

  const value = ref(init ? init() : undefined) as Ref<T>
  context.state.set(key, value as Ref<unknown>)
  return value
}

/** Client-safe runtime configuration. Only explicitly supplied public values exist here. */
export const useLiveRuntimeConfig = <T extends LiveRuntimeConfig = LiveRuntimeConfig>(): T => {
  return readonly(currentContext().runtimeConfig) as T
}

/**
 * Nuxt useAsyncData pattern: keyed dedupe, reactive status/error/data, abortable
 * refresh, and cache sharing between components in the same LiveVue app.
 */
export const useLiveAsyncData = <T>(
  key: string,
  handler: LiveAsyncHandler<T>,
  options: { immediate?: boolean } = {}
): LiveAsyncData<T> => {
  if (!key) throw new Error("useLiveAsyncData requires a non-empty key")
  const context = currentContext()
  const existing = context.asyncData.get(key)
  if (existing) return existing as AsyncEntry<T>

  const data = shallowRef<T>()
  const error = shallowRef<unknown>()
  const status = ref<LiveAsyncStatus>("idle")

  const entry: AsyncEntry<T> = {
    data,
    error,
    status,
    pending: computed(() => status.value === "pending"),
    refresh: async () => {
      if (entry.promise) return entry.promise

      entry.controller?.abort()
      entry.controller = new AbortController()
      status.value = "pending"
      error.value = undefined

      entry.promise = handler({ signal: entry.controller.signal })
        .then((value) => {
          data.value = value
          status.value = "success"
          return value
        })
        .catch((reason) => {
          if (entry.controller?.signal.aborted) return data.value
          error.value = reason
          status.value = "error"
          return undefined
        })
        .finally(() => {
          entry.promise = undefined
        })

      return entry.promise
    },
    clear: () => {
      entry.controller?.abort()
      entry.controller = undefined
      entry.promise = undefined
      data.value = undefined
      error.value = undefined
      status.value = "idle"
    },
  }

  context.asyncData.set(key, entry as AsyncEntry<unknown>)
  if (options.immediate !== false) void entry.refresh()
  return entry
}

/** Nuxt useFetch pattern with injectable transport for Phoenix/Ash consumers. */
export const useLiveFetch = <T = unknown>(url: string, options: LiveFetchOptions = {}): LiveAsyncData<T> => {
  const context = currentContext()
  const { key, immediate, parse = "json", ...requestInit } = options
  const method = (requestInit.method || "GET").toUpperCase()
  const cacheKey = key || `${method}:${url}`
  const fetcher = context.fetch || globalThis.fetch

  if (!fetcher) throw new Error("useLiveFetch requires a fetch implementation")

  return useLiveAsyncData<T>(
    cacheKey,
    async ({ signal }) => {
      const response = await fetcher(url, { ...requestInit, signal })
      if (!response.ok) throw new Error(`LiveVue fetch failed: ${response.status} ${response.statusText}`)
      return (parse === "text" ? await response.text() : await response.json()) as T
    },
    { immediate }
  )
}

/** Nuxt defineNuxtPlugin pattern without inventing a second plugin runtime. */
export const defineLiveVuePlugin = (plugin: Plugin): Plugin => plugin

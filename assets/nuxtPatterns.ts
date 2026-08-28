import {
  computed,
  defineComponent,
  h,
  inject,
  onErrorCaptured,
  readonly,
  ref,
  shallowRef,
  type App,
  type Component,
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

export type LiveHeadMeta = {
  name?: string
  property?: string
  content: string
}

export type LiveHeadLink = {
  rel: string
  href: string
  type?: string
  media?: string
}

export type LiveHead = {
  title?: string
  meta?: LiveHeadMeta[]
  link?: LiveHeadLink[]
}

export type LiveRouteLocation = {
  path: string
  params?: Record<string, string>
  query?: Record<string, string | string[]>
  meta?: Record<string, unknown>
}

export type LiveRouteRedirect = {
  redirect: string
  replace?: boolean
}

export type LiveRouteAbort = {
  abort: true
  reason?: string
}

export type LiveRouteMiddlewareResult = void | true | LiveRouteRedirect | LiveRouteAbort
export type LiveRouteMiddleware = (
  to: Readonly<LiveRouteLocation>,
  from?: Readonly<LiveRouteLocation>
) => LiveRouteMiddlewareResult | Promise<LiveRouteMiddlewareResult>

export type LiveError = {
  message: string
  statusCode?: number
  statusMessage?: string
  fatal?: boolean
  cause?: unknown
}

export type LivePayload = {
  version: 1
  state: Record<string, unknown>
  asyncData: Record<string, unknown>
  once: Record<string, unknown>
  layout?: string
  head?: LiveHead
}

export type LiveServerBackend =
  | { kind: "phoenix"; handler: string }
  | { kind: "ash"; domain: string; resource: string; action: string }

export type LiveServerOperation<Input, Output> = Readonly<{
  id: string
  subject: string
  backend: LiveServerBackend
  consequential?: boolean
  __input?: (input: Input) => void
  __output?: () => Output
}>

export type LiveServerOperationReceipt = {
  digest: string
  operation_id: string
  subject: string
  correlation_id?: string
  status: "ok" | "error"
  executed: boolean
}

export type LiveServerOperationResponse<T> = {
  data: T
  receipt: LiveServerOperationReceipt
}

export type LiveServerOperationTransport = (
  operation: LiveServerOperation<unknown, unknown>,
  input: unknown,
  options: { signal?: AbortSignal; correlationId?: string }
) => Promise<LiveServerOperationResponse<unknown>>

export type NuxtPatternOptions = {
  runtimeConfig?: Record<string, unknown>
  fetch?: typeof globalThis.fetch
  layouts?: Record<string, Component>
  defaultLayout?: string
  routeMiddleware?: Record<string, LiveRouteMiddleware>
  initialPayload?: LivePayload | string
  serverOperationTransport?: LiveServerOperationTransport
  serverOperationEndpoint?: string
}

type AsyncEntry<T> = LiveAsyncData<T> & {
  controller?: AbortController
  promise?: Promise<T | undefined>
}

type NuxtPatternContext = {
  state: Map<string, Ref<unknown>>
  asyncData: Map<string, AsyncEntry<unknown>>
  hydratedAsyncData: Map<string, unknown>
  runtimeConfig: LiveRuntimeConfig
  fetch?: typeof globalThis.fetch
  layouts: Map<string, Component>
  layout: Ref<string>
  routeMiddleware: Map<string, LiveRouteMiddleware>
  head: ShallowRef<LiveHead>
  error: ShallowRef<LiveError | undefined>
  oncePromises: Map<string, Promise<unknown>>
  onceValues: Map<string, unknown>
  serverOperationTransport?: LiveServerOperationTransport
  serverOperationEndpoint: string
}

const contextKey = Symbol("LiveVueNuxtPatterns")

const currentContext = (): NuxtPatternContext => {
  const context = inject<NuxtPatternContext | undefined>(contextKey, undefined)
  if (!context) throw new Error("Nuxt-style LiveVue composables require createNuxtPatternsPlugin()")
  return context
}

const nonempty = (value: string, label: string) => {
  if (!value || !value.trim()) throw new Error(`${label} requires a non-empty value`)
}

const jsonClone = <T>(value: T, label: string): T => {
  const encoded = JSON.stringify(value)
  if (encoded === undefined) throw new Error(`${label} is not JSON serializable`)
  return JSON.parse(encoded) as T
}

const parsePayload = (payload: LivePayload | string): LivePayload => {
  const parsed = typeof payload === "string" ? (JSON.parse(payload) as LivePayload) : payload
  if (!parsed || parsed.version !== 1) throw new Error("Unsupported LiveVue payload version")
  return parsed
}

const hydrateContext = (context: NuxtPatternContext, source: LivePayload | string) => {
  const payload = parsePayload(source)

  for (const [key, value] of Object.entries(payload.state || {})) {
    const cloned = jsonClone(value, `state:${key}`)
    const existing = context.state.get(key)
    if (existing) existing.value = cloned
    else context.state.set(key, ref(cloned) as Ref<unknown>)
  }

  for (const [key, value] of Object.entries(payload.asyncData || {})) {
    const cloned = jsonClone(value, `asyncData:${key}`)
    context.hydratedAsyncData.set(key, cloned)
    const existing = context.asyncData.get(key)
    if (existing) {
      existing.data.value = cloned
      existing.error.value = undefined
      existing.status.value = "success"
    }
  }

  for (const [key, value] of Object.entries(payload.once || {})) {
    const cloned = jsonClone(value, `once:${key}`)
    context.onceValues.set(key, cloned)
    context.oncePromises.set(key, Promise.resolve(cloned))
  }

  if (payload.layout) {
    if (context.layouts.size > 0 && !context.layouts.has(payload.layout)) {
      throw new Error(`Unknown LiveVue layout ${payload.layout}`)
    }
    context.layout.value = payload.layout
  }

  if (payload.head) context.head.value = jsonClone(payload.head, "head")
}

/**
 * Creates a per-Vue-app context inspired by Nuxt's request-scoped app state.
 * State, payloads, once-calls and async caches live on the Vue app instance,
 * never in module globals, so SSR applications do not share request state.
 */
export const createNuxtPatternsPlugin = (options: NuxtPatternOptions = {}): Plugin => ({
  install(app: App) {
    const layouts = new Map(Object.entries(options.layouts || {}))
    const defaultLayout =
      options.defaultLayout || (layouts.has("default") ? "default" : layouts.keys().next().value || "default")

    if (layouts.size > 0 && !layouts.has(defaultLayout)) {
      throw new Error(`Unknown default LiveVue layout ${defaultLayout}`)
    }

    const context: NuxtPatternContext = {
      state: new Map(),
      asyncData: new Map(),
      hydratedAsyncData: new Map(),
      runtimeConfig: Object.freeze({ ...(options.runtimeConfig || {}) }),
      fetch: options.fetch,
      layouts,
      layout: ref(defaultLayout),
      routeMiddleware: new Map(Object.entries(options.routeMiddleware || {})),
      head: shallowRef({}),
      error: shallowRef(),
      oncePromises: new Map(),
      onceValues: new Map(),
      serverOperationTransport: options.serverOperationTransport,
      serverOperationEndpoint: options.serverOperationEndpoint || "/live_vue/operations",
    }

    if (options.initialPayload) hydrateContext(context, options.initialPayload)
    app.provide(contextKey, context)
  },
})

/** Nuxt useState pattern, scoped to one LiveVue application instance. */
export const useLiveState = <T>(key: string, init?: () => T): Ref<T> => {
  nonempty(key, "useLiveState key")
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
 * refresh, payload hydration, and cache sharing inside one LiveVue app.
 */
export const useLiveAsyncData = <T>(
  key: string,
  handler: LiveAsyncHandler<T>,
  options: { immediate?: boolean } = {}
): LiveAsyncData<T> => {
  nonempty(key, "useLiveAsyncData key")
  const context = currentContext()
  const existing = context.asyncData.get(key)
  if (existing) return existing as AsyncEntry<T>

  const hasHydratedValue = context.hydratedAsyncData.has(key)
  const data = shallowRef<T | undefined>(hasHydratedValue ? (context.hydratedAsyncData.get(key) as T) : undefined)
  const error = shallowRef<unknown>()
  const status = ref<LiveAsyncStatus>(hasHydratedValue ? "success" : "idle")

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
          context.hydratedAsyncData.delete(key)
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
      context.hydratedAsyncData.delete(key)
      data.value = undefined
      error.value = undefined
      status.value = "idle"
    },
  }

  context.asyncData.set(key, entry as AsyncEntry<unknown>)
  if (options.immediate !== false && !hasHydratedValue) void entry.refresh()
  return entry
}

/** Nuxt useFetch pattern with injectable transport for Phoenix/Ash consumers. */
export const useLiveFetch = <T = unknown>(url: string, options: LiveFetchOptions = {}): LiveAsyncData<T> => {
  nonempty(url, "useLiveFetch URL")
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

/** Nuxt layout selection, backed by an app-scoped component registry. */
export const useLiveLayout = () => {
  const context = currentContext()
  return {
    name: readonly(context.layout),
    set: (name: string) => {
      nonempty(name, "layout")
      if (!context.layouts.has(name)) throw new Error(`Unknown LiveVue layout ${name}`)
      context.layout.value = name
    },
    resolve: (name = context.layout.value) => context.layouts.get(name),
  }
}

export const LiveVueLayout = defineComponent({
  name: "LiveVueLayout",
  setup(_, { slots }) {
    const context = currentContext()
    return () => {
      const layout = context.layouts.get(context.layout.value)
      return layout ? h(layout, null, slots) : slots.default?.()
    }
  },
})

/** Nuxt route middleware pattern. It returns navigation intent; it never actuates Phoenix routing. */
export const defineLiveRouteMiddleware = (middleware: LiveRouteMiddleware): LiveRouteMiddleware => middleware

export const runLiveRouteMiddleware = async (
  names: string | string[],
  to: LiveRouteLocation,
  from?: LiveRouteLocation
): Promise<LiveRouteMiddlewareResult> => {
  nonempty(to.path, "route path")
  if (!to.path.startsWith("/")) throw new Error("LiveVue route middleware requires an absolute route path")

  const context = currentContext()
  for (const name of Array.isArray(names) ? names : [names]) {
    const middleware = context.routeMiddleware.get(name)
    if (!middleware) throw new Error(`Unknown LiveVue route middleware ${name}`)
    const result = await middleware(Object.freeze({ ...to }), from ? Object.freeze({ ...from }) : undefined)
    if (result !== undefined && result !== true) return result
  }
  return undefined
}

/** Applies only LiveVue-owned head elements, leaving unrelated Phoenix/application tags untouched. */
export const applyLiveHead = (head: LiveHead, doc: Document = document) => {
  for (const element of Array.from(doc.head.querySelectorAll("[data-live-vue-head]"))) element.remove()
  if (head.title !== undefined) doc.title = head.title

  for (const meta of head.meta || []) {
    const element = doc.createElement("meta")
    if (meta.name) element.setAttribute("name", meta.name)
    if (meta.property) element.setAttribute("property", meta.property)
    element.setAttribute("content", meta.content)
    element.setAttribute("data-live-vue-head", "meta")
    doc.head.appendChild(element)
  }

  for (const link of head.link || []) {
    const element = doc.createElement("link")
    element.setAttribute("rel", link.rel)
    element.setAttribute("href", link.href)
    if (link.type) element.setAttribute("type", link.type)
    if (link.media) element.setAttribute("media", link.media)
    element.setAttribute("data-live-vue-head", "link")
    doc.head.appendChild(element)
  }
}

/** Nuxt useHead pattern with SSR-safe app state and deterministic client reconciliation. */
export const useLiveHead = (head: LiveHead) => {
  const context = currentContext()
  context.head.value = jsonClone(head, "head")
  if (typeof document !== "undefined") applyLiveHead(context.head.value, document)
  return readonly(context.head)
}

const normalizeLiveError = (error: unknown): LiveError => {
  if (error instanceof Error) return { message: error.message, cause: error }
  if (typeof error === "string") return { message: error }
  if (error && typeof error === "object" && "message" in error) {
    const candidate = error as Partial<LiveError>
    return {
      message: String(candidate.message),
      statusCode: candidate.statusCode,
      statusMessage: candidate.statusMessage,
      fatal: candidate.fatal,
      cause: candidate.cause,
    }
  }
  return { message: String(error), cause: error }
}

/** Nuxt-style application error state with explicit show/clear operations. */
export const useLiveError = () => {
  const context = currentContext()
  return {
    error: readonly(context.error),
    show: (error: unknown) => {
      context.error.value = normalizeLiveError(error)
      return context.error.value
    },
    clear: () => {
      context.error.value = undefined
    },
  }
}

export const showLiveError = (error: unknown) => useLiveError().show(error)
export const clearLiveError = () => useLiveError().clear()

export const LiveVueErrorBoundary = defineComponent({
  name: "LiveVueErrorBoundary",
  setup(_, { slots }) {
    const context = currentContext()
    const clear = () => {
      context.error.value = undefined
    }

    onErrorCaptured((error) => {
      context.error.value = normalizeLiveError(error)
      return false
    })

    return () => {
      const error = context.error.value
      if (error) return slots.error?.({ error, clear }) ?? null
      return slots.default?.() ?? null
    }
  },
})

/** Nuxt callOnce pattern: one promise/result per app/request key, retrying only after failure. */
export const callLiveOnce = <T>(key: string, factory: () => T | Promise<T>): Promise<T> => {
  nonempty(key, "callLiveOnce key")
  const context = currentContext()
  if (context.oncePromises.has(key)) return context.oncePromises.get(key) as Promise<T>
  if (context.onceValues.has(key)) return Promise.resolve(context.onceValues.get(key) as T)

  const promise = Promise.resolve()
    .then(factory)
    .then((value) => {
      context.onceValues.set(key, value)
      return value
    })
    .catch((error) => {
      context.oncePromises.delete(key)
      throw error
    })

  context.oncePromises.set(key, promise as Promise<unknown>)
  return promise
}

/** Manufactures a JSON-safe SSR payload from app-scoped state without serializing errors or authority. */
export const dehydrateLivePayload = (): LivePayload => {
  const context = currentContext()
  const state: Record<string, unknown> = {}
  const asyncData: Record<string, unknown> = {}
  const once: Record<string, unknown> = {}

  for (const [key, value] of context.state) {
    if (value.value !== undefined) state[key] = jsonClone(value.value, `state:${key}`)
  }

  for (const [key, entry] of context.asyncData) {
    if (entry.status.value === "success" && entry.data.value !== undefined) {
      asyncData[key] = jsonClone(entry.data.value, `asyncData:${key}`)
    }
  }

  for (const [key, value] of context.hydratedAsyncData) {
    if (!(key in asyncData) && value !== undefined) asyncData[key] = jsonClone(value, `asyncData:${key}`)
  }

  for (const [key, value] of context.onceValues) {
    if (value !== undefined) once[key] = jsonClone(value, `once:${key}`)
  }

  return {
    version: 1,
    state,
    asyncData,
    once,
    layout: context.layout.value,
    head: jsonClone(context.head.value, "head"),
  }
}

export const serializeLivePayload = () =>
  JSON.stringify(dehydrateLivePayload())
    .replace(/</g, "\\u003c")
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029")

export const hydrateLivePayload = (payload: LivePayload | string) => {
  const context = currentContext()
  hydrateContext(context, payload)
  if (typeof document !== "undefined" && context.head.value) applyLiveHead(context.head.value, document)
}

/** Defines a compile-time typed Phoenix/Ash operation while preserving runtime identity. */
export const defineLiveServerOperation = <Input, Output>(
  operation: Omit<LiveServerOperation<Input, Output>, "__input" | "__output">
): LiveServerOperation<Input, Output> => {
  nonempty(operation.id, "server operation id")
  nonempty(operation.subject, "server operation subject")

  if (operation.backend.kind === "phoenix") {
    nonempty(operation.backend.handler, "Phoenix handler identity")
  } else if (operation.backend.kind === "ash") {
    nonempty(operation.backend.domain, "Ash domain identity")
    nonempty(operation.backend.resource, "Ash resource identity")
    nonempty(operation.backend.action, "Ash action identity")
  } else {
    throw new Error("Unsupported LiveVue server operation backend")
  }

  return Object.freeze({ ...operation }) as LiveServerOperation<Input, Output>
}

/**
 * Executes a typed server-operation request through an injected transport or the
 * default Phoenix HTTP seam. Descriptor metadata is identity, never ambient authority.
 */
export const callLiveServerOperation = async <Input, Output>(
  operation: LiveServerOperation<Input, Output>,
  input: Input,
  options: { signal?: AbortSignal; correlationId?: string } = {}
): Promise<LiveServerOperationResponse<Output>> => {
  const context = currentContext()

  if (context.serverOperationTransport) {
    return (await context.serverOperationTransport(
      operation as LiveServerOperation<unknown, unknown>,
      input,
      options
    )) as LiveServerOperationResponse<Output>
  }

  const fetcher = context.fetch || globalThis.fetch
  if (!fetcher) throw new Error("callLiveServerOperation requires a transport or fetch implementation")

  const endpoint = `${context.serverOperationEndpoint.replace(/\/$/, "")}/${encodeURIComponent(operation.id)}`
  const response = await fetcher(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    signal: options.signal,
    body: JSON.stringify({
      operation: {
        id: operation.id,
        subject: operation.subject,
        backend: operation.backend,
        consequential: operation.consequential === true,
      },
      input,
      correlation_id: options.correlationId,
    }),
  })

  const payload = (await response.json()) as {
    data?: Output
    error?: string
    receipt?: LiveServerOperationReceipt
  }

  if (!response.ok || payload.error) {
    throw new Error(payload.error || `LiveVue server operation failed: ${response.status} ${response.statusText}`)
  }
  if (!payload.receipt) throw new Error("LiveVue server operation response is missing its receipt")

  return { data: payload.data as Output, receipt: payload.receipt }
}

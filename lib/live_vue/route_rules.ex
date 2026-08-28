defmodule LiveVue.RouteRules do
  @moduledoc """
  Phoenix-native route policy inspired by Nuxt route rules.

  Rules are data, not a second router. Phoenix remains authoritative for route
  dispatch while LiveVue can project matched metadata into SSR, caching and
  response-header behavior.
  """

  alias Plug.Conn

  @enforce_keys [:pattern]
  defstruct [:pattern, :ssr, :cache, headers: %{}]

  @type t :: %__MODULE__{
          pattern: String.t(),
          ssr: boolean() | nil,
          cache: non_neg_integer() | false | nil,
          headers: %{optional(String.t()) => String.t()}
        }

  @spec new(String.t(), keyword()) :: {:ok, t()} | {:error, atom()}
  def new(pattern, opts \\ []) when is_binary(pattern) do
    with :ok <- validate_pattern(pattern),
         :ok <- validate_ssr(opts[:ssr]),
         :ok <- validate_cache(opts[:cache]),
         {:ok, headers} <- normalize_headers(opts[:headers] || %{}) do
      {:ok, %__MODULE__{pattern: pattern, ssr: opts[:ssr], cache: opts[:cache], headers: headers}}
    end
  end

  @spec new!(String.t(), keyword()) :: t()
  def new!(pattern, opts \\ []) do
    case new(pattern, opts) do
      {:ok, rule} -> rule
      {:error, reason} -> raise ArgumentError, "invalid LiveVue route rule: #{inspect(reason)}"
    end
  end

  @doc "Returns the most-specific matching rule for a request path."
  @spec match([t()], String.t()) :: t() | nil
  def match(rules, path) when is_list(rules) and is_binary(path) do
    rules
    |> Enum.filter(&matches?(&1.pattern, path))
    |> Enum.max_by(&specificity(&1.pattern), fn -> nil end)
  end

  @doc "Applies response-safe route policy and stores the full rule in conn.private."
  @spec apply(Conn.t(), [t()]) :: Conn.t()
  def apply(%Conn{} = conn, rules) do
    case match(rules, conn.request_path) do
      nil -> conn
      rule ->
        conn
        |> Conn.put_private(:live_vue_route_rule, rule)
        |> apply_headers(rule.headers)
        |> apply_cache(rule.cache)
    end
  end

  @spec ssr?(Conn.t(), boolean()) :: boolean()
  def ssr?(%Conn{} = conn, default \\ true) do
    case conn.private[:live_vue_route_rule] do
      %__MODULE__{ssr: value} when is_boolean(value) -> value
      _ -> default
    end
  end

  defp apply_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {name, value}, acc -> Conn.put_resp_header(acc, name, value) end)
  end

  defp apply_cache(conn, nil), do: conn
  defp apply_cache(conn, false), do: Conn.put_resp_header(conn, "cache-control", "no-store")

  defp apply_cache(conn, seconds) when is_integer(seconds) do
    Conn.put_resp_header(conn, "cache-control", "public, max-age=#{seconds}")
  end

  defp matches?(pattern, path) do
    cond do
      String.ends_with?(pattern, "/**") ->
        prefix = String.trim_trailing(pattern, "**")
        path == String.trim_trailing(prefix, "/") or String.starts_with?(path, prefix)

      String.ends_with?(pattern, "/*") ->
        prefix = String.trim_trailing(pattern, "*")

        if String.starts_with?(path, prefix) do
          suffix = String.trim_leading(path, prefix)
          suffix != "" and not String.contains?(suffix, "/")
        else
          false
        end

      true ->
        pattern == path
    end
  end

  defp specificity(pattern), do: pattern |> String.replace("*", "") |> byte_size()

  defp validate_pattern("/" <> _), do: :ok
  defp validate_pattern(_), do: {:error, :absolute_pattern_required}

  defp validate_ssr(nil), do: :ok
  defp validate_ssr(value) when is_boolean(value), do: :ok
  defp validate_ssr(_), do: {:error, :invalid_ssr_policy}

  defp validate_cache(nil), do: :ok
  defp validate_cache(false), do: :ok
  defp validate_cache(value) when is_integer(value) and value >= 0, do: :ok
  defp validate_cache(_), do: {:error, :invalid_cache_policy}

  defp normalize_headers(headers) when is_map(headers) do
    Enum.reduce_while(headers, {:ok, %{}}, fn
      {name, value}, {:ok, acc} when is_binary(name) and is_binary(value) ->
        {:cont, {:ok, Map.put(acc, String.downcase(name), value)}}

      _, _ ->
        {:halt, {:error, :invalid_headers}}
    end)
  end

  defp normalize_headers(_), do: {:error, :invalid_headers}
end

defmodule LiveVue.RouteRules.Plug do
  @moduledoc """
  Applies `LiveVue.RouteRules` without replacing Phoenix routing.

      plug LiveVue.RouteRules.Plug,
        rules: [LiveVue.RouteRules.new!("/blog/**", cache: 60)]
  """

  @behaviour Plug

  @impl true
  def init(opts), do: Keyword.fetch!(opts, :rules)

  @impl true
  def call(conn, rules), do: LiveVue.RouteRules.apply(conn, rules)
end

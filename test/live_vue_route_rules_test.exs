defmodule LiveVue.RouteRulesTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias LiveVue.RouteRules

  test "chooses the most-specific matching wildcard rule" do
    rules = [
      RouteRules.new!("/blog/**", cache: 60),
      RouteRules.new!("/blog/private/**", cache: false, ssr: false)
    ]

    assert %RouteRules{pattern: "/blog/private/**"} = RouteRules.match(rules, "/blog/private/draft")
    assert %RouteRules{pattern: "/blog/**"} = RouteRules.match(rules, "/blog/post-1")
  end

  test "single-star rule matches exactly one path segment" do
    rule = RouteRules.new!("/users/*")

    assert ^rule = RouteRules.match([rule], "/users/7")
    assert nil == RouteRules.match([rule], "/users/7/settings")
  end

  test "applies cache headers and preserves the rule as Phoenix private metadata" do
    rule = RouteRules.new!("/docs/**", cache: 120, headers: %{"X-LiveVue-Policy" => "docs"})

    conn =
      conn(:get, "/docs/intro")
      |> RouteRules.apply([rule])

    assert conn.private[:live_vue_route_rule] == rule
    assert get_resp_header(conn, "cache-control") == ["public, max-age=120"]
    assert get_resp_header(conn, "x-livevue-policy") == ["docs"]
  end

  test "cache false emits no-store and ssr policy is explicit" do
    rule = RouteRules.new!("/client/**", cache: false, ssr: false)
    conn = conn(:get, "/client/editor") |> RouteRules.apply([rule])

    assert get_resp_header(conn, "cache-control") == ["no-store"]
    refute RouteRules.ssr?(conn)
  end

  test "unmatched routes preserve caller SSR default" do
    conn = conn(:get, "/ordinary") |> RouteRules.apply([])

    assert RouteRules.ssr?(conn)
    refute RouteRules.ssr?(conn, false)
  end

  test "rejects unsafe or malformed route policy" do
    assert {:error, :absolute_pattern_required} = RouteRules.new("relative/**")
    assert {:error, :invalid_cache_policy} = RouteRules.new("/x", cache: -1)
    assert {:error, :invalid_ssr_policy} = RouteRules.new("/x", ssr: :sometimes)
    assert {:error, :invalid_headers} = RouteRules.new("/x", headers: %{x: "not-binary-name"})
  end
end

import { expect, test } from "vitest"
import pkg from "../../package.json" with { type: "json" }

test("package keeps vitePlugin consumer export", () => {
  expect(pkg.exports["./vitePlugin"].import).toBe("./assets/vitePlugin.js")
})

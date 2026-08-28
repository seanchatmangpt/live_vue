import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("Vitest remains the canonical frontend verifier", () => {
  const pkg = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8"))
  expect(pkg.scripts.test).toBe("vitest")
})

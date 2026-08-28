import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("root contract exports getHooks", () => {
  const source = readFileSync(new URL("../index.ts", import.meta.url), "utf8")
  expect(source).toContain("export { getHooks }")
})

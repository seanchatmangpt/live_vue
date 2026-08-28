import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("root contract keeps Link public", () => {
  const source = readFileSync(new URL("../index.ts", import.meta.url), "utf8")
  expect(source).toContain("export { default as Link }")
})

import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("package keeps server consumer export", () => {
  const pkg = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8"))
  expect(pkg.exports["./server"].import).toBe("./assets/server.ts")
})

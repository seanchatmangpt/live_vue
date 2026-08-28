import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("Vue peer compatibility floor stays explicit", () => {
  const pkg = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8"))
  expect(pkg.peerDependencies.vue).toBe("^3.4.0")
})

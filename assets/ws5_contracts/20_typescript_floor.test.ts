import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("TypeScript compatibility floor stays explicit", () => {
  const pkg = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8"))
  expect(pkg.devDependencies.typescript).toBe("^5.6.2")
})

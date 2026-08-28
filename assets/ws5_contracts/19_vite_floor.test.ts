import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("Vite compatibility floor stays explicit", () => {
  const pkg = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8"))
  expect(pkg.devDependencies.vite).toBe("^6.3.0")
})

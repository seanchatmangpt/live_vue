import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("main and types stay on the same TypeScript root", () => {
  const pkg = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8"))
  expect(pkg.main).toBe("assets/index.ts")
  expect(pkg.types).toBe("assets/index.ts")
})

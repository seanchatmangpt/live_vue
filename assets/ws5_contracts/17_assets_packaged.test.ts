import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("npm package keeps the assets tree", () => {
  const pkg = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8"))
  expect(pkg.files).toContain("assets")
})

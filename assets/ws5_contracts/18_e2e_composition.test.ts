import { expect, test } from "vitest"
import { readFileSync } from "node:fs"

test("E2E test composes build before Playwright", () => {
  const pkg = JSON.parse(readFileSync(new URL("../../package.json", import.meta.url), "utf8"))
  expect(pkg.scripts["e2e:test"]).toBe("npm run e2e:build && npx playwright test --config test/e2e/playwright.config.js")
})

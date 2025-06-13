import { test, expect } from "../test-fixtures";
import { syncLV, evalLV } from "../utils";

test("renders modal inside portal location", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  await expect(page.locator("#my-modal")).toHaveCount(1);
  await expect(page.locator("#my-modal-content")).toBeHidden();
  // no modal inside the main element (rendered in the layout)
  await expect(page.locator("main #my-modal")).toHaveCount(0);

  await page.getByRole("button", { name: "Open modal" }).click();
  await expect(page.locator("#my-modal-content")).toBeVisible();

  await expect(page.locator("#my-modal-content")).toContainText(
    "DOM patching works as expected: 0",
  );
  await evalLV(page, "send(self(), :tick)");
  await expect(page.locator("#my-modal-content")).toContainText(
    "DOM patching works as expected: 1",
  );
});

test("tooltip example", async ({ page }) => {
  await page.goto("/portal?tick=false");
  await syncLV(page);

  await expect(page.locator("#tooltip-example-portal")).toBeHidden();
  await expect(page.locator("#tooltip-example-no-portal")).toBeHidden();

  await page.getByRole("button", { name: "Hover me", exact: true }).hover();
  await expect(page.locator("#tooltip-example-portal")).toBeVisible();
  await expect(page.locator("#tooltip-example-no-portal")).toBeHidden();

  await page.getByRole("button", { name: "Hover me (no portal)" }).hover();
  await expect(page.locator("#tooltip-example-portal")).toBeHidden();
  await expect(page.locator("#tooltip-example-no-portal")).toBeVisible();
});

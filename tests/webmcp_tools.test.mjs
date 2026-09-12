import assert from "node:assert/strict";
import test from "node:test";

import {
  createLastSlotTools,
  registerLastSlotTools,
} from "../apps/web/web/webmcp-tools.js";

test("exposes the Last Slot project thesis as a read-only WebMCP tool", async () => {
  const tools = createLastSlotTools();
  const overview = tools.find((tool) => tool.name === "get_project_overview");

  assert.ok(overview);
  assert.deepEqual(overview.annotations, {
    readOnlyHint: true,
    untrustedContentHint: false,
  });

  const result = JSON.parse(await overview.execute({}));
  assert.equal(result.project, "Last Slot");
  assert.equal(result.thesis, "One slot. Two browsers. One correct result.");
  assert.match(result.summary, /zero-retry browser automation/);
  assert.equal(result.status, "executable proof");
});

test("returns bounded evidence for a named reliability claim", async () => {
  const evidence = createLastSlotTools().find(
    (tool) => tool.name === "get_claim_evidence",
  );

  assert.ok(evidence);
  assert.deepEqual(evidence.inputSchema.properties.claim.enum, [
    "concurrency",
    "idempotency",
    "user_journey",
  ]);

  const result = JSON.parse(await evidence.execute({ claim: "concurrency" }));
  assert.equal(result.claim, "concurrency");
  assert.match(result.proof, /201.*409/);
  assert.match(result.artifact, /http_integration\.sh/);
  assert.match(result.limit, /synthetic/i);
});

test("registers a small non-overlapping tool set when WebMCP is available", async () => {
  const registered = [];
  const modelContext = {
    registerTool: async (tool) => registered.push(tool),
  };

  const count = await registerLastSlotTools(modelContext);

  assert.equal(count, 4);
  assert.deepEqual(
    registered.map((tool) => tool.name),
    [
      "get_project_overview",
      "get_claim_evidence",
      "get_project_limits",
      "get_reproduction_steps",
    ],
  );
  for (const tool of registered) {
    assert.ok(tool.description.length <= 500);
    assert.ok(tool.name.length <= 30);
    const input =
      tool.name === "get_claim_evidence" ? { claim: "concurrency" } : {};
    assert.ok((await tool.execute(input)).length <= 1500);
  }
});

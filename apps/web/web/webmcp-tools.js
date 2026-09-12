const READ_ONLY_ANNOTATIONS = Object.freeze({
  readOnlyHint: true,
  untrustedContentHint: false,
});

const CLAIM_EVIDENCE = Object.freeze({
  concurrency: {
    proof:
      "A best-effort barrier releases two competing HTTP requests; the public API returns one 201 and one 409, and PostgreSQL contains exactly one booking row.",
    artifact:
      "https://github.com/hoppworks/last-slot/blob/main/scripts/http_integration.sh",
    limit:
      "The proof uses synthetic data in a local containerized stack and does not prove simultaneous arrival.",
  },
  idempotency: {
    proof:
      "Replaying the same Idempotency-Key returns 201 then 200 with the same booking ID while PostgreSQL still contains one row.",
    artifact:
      "https://github.com/hoppworks/last-slot/blob/main/scripts/http_integration.sh",
    limit: "The case study does not claim a production payment or retry system.",
  },
  user_journey: {
    proof:
      "A zero-retry Patrol run drives two independent browser pages one after the other, then fresh visitor and admin pages read the persisted winner through the public application path.",
    artifact:
      "https://github.com/hoppworks/last-slot/blob/main/apps/web/patrol_test/last_slot_test.dart",
    limit: "The browser journey proves observable behavior, not the database row count by itself.",
  },
});

export function createLastSlotTools() {
  return [
    {
      name: "get_project_overview",
      description:
        "Summarize the Last Slot reliability case study, its evidence boundary, and Daniel Hopp's engineering contribution.",
      inputSchema: {
        type: "object",
        properties: {},
        additionalProperties: false,
      },
      annotations: READ_ONLY_ANNOTATIONS,
      execute: async () =>
        JSON.stringify({
          project: "Last Slot",
          thesis: "One slot. Two browsers. One correct result.",
          status: "executable proof",
          summary:
            "An intentionally small Rust, Flutter, and PostgreSQL reliability case study: a unique constraint decides the race, and zero-retry browser automation, public readback, and a separate HTTP/database proof make the result inspectable end to end.",
          contribution:
            "Daniel Hopp designed the case study, architecture, API and database contracts, and the proof design. Parts of the implementation were built with coding agents under his review.",
        }),
    },
    {
      name: "get_claim_evidence",
      description:
        "Return the proof artifact and explicit limit for one Last Slot reliability claim: concurrency, idempotency, or the browser journey.",
      inputSchema: {
        type: "object",
        properties: {
          claim: {
            type: "string",
            enum: ["concurrency", "idempotency", "user_journey"],
            description: "Reliability claim to inspect.",
          },
        },
        required: ["claim"],
        additionalProperties: false,
      },
      annotations: READ_ONLY_ANNOTATIONS,
      execute: async ({ claim }) => {
        const evidence = CLAIM_EVIDENCE[claim];
        if (!evidence) {
          throw new TypeError(
            "Unknown claim. Use concurrency, idempotency, or user_journey.",
          );
        }
        return JSON.stringify({ claim, ...evidence });
      },
    },
    {
      name: "get_project_limits",
      description:
        "List the deliberate boundaries and unsupported production claims of the Last Slot case study.",
      inputSchema: {
        type: "object",
        properties: {},
        additionalProperties: false,
      },
      annotations: READ_ONLY_ANNOTATIONS,
      execute: async () =>
        JSON.stringify({
          project: "Last Slot",
          limits: [
            "Synthetic demonstration data only",
            "No authentication or payment flow",
            "No high-availability, uptime, or load-test claim",
            "Deployable Docker Compose case study, not a public multi-tenant booking product",
          ],
          reason:
            "The simple product scenario keeps the complete browser-to-database evidence path inspectable.",
        }),
    },
    {
      name: "get_reproduction_steps",
      description:
        "Return the prerequisites, command, and report location for reproducing the complete Last Slot proof locally.",
      inputSchema: {
        type: "object",
        properties: {},
        additionalProperties: false,
      },
      annotations: READ_ONLY_ANNOTATIONS,
      execute: async () =>
        JSON.stringify({
          prerequisites: ["Docker Compose", "Flutter 3.44.2", "Node.js 22"],
          command: "bash scripts/e2e.sh",
          report: "build/playwright/html/index.html",
          verifies:
            "Rust and Flutter checks, HTTP/database concurrency and idempotency proof, and the zero-retry sequential two-page Patrol journey.",
          source: "https://github.com/hoppworks/last-slot",
        }),
    },
  ];
}

export async function registerLastSlotTools(modelContext) {
  if (!modelContext?.registerTool) return 0;

  const tools = createLastSlotTools();
  for (const tool of tools) {
    await modelContext.registerTool(tool);
  }
  return tools.length;
}

if (typeof document !== "undefined") {
  void registerLastSlotTools(document.modelContext).catch((error) => {
    console.warn("Last Slot WebMCP tools could not be registered.", error);
  });
}

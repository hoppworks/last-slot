# WebMCP

Last Slot progressively exposes four read-only tools to compatible browser
agents:

- `get_project_overview`
- `get_claim_evidence`
- `get_project_limits`
- `get_reproduction_steps`

The tools return bounded, structured evidence. They do not book appointments,
change application state, read user data, or call the Last Slot API. Each tool
is marked `readOnlyHint: true` and `untrustedContentHint: false`.

The standard Flutter application remains the fallback. When
`document.modelContext` is unavailable, the registration module performs no
work and the booking UI behaves as before.

## Local verification

Run the deterministic contract tests:

```bash
node --test tests/webmcp_tools.test.mjs
```

To inspect registered tools in Chrome, enable
`chrome://flags/#enable-webmcp-testing`, relaunch Chrome, serve the application,
and use Chrome's Model Context Tool Inspector extension.

## Deployment boundary

The Nginx deployment explicitly keeps the document in an origin-keyed agent
cluster and limits the `tools` permissions policy to the same origin. WebMCP is
still experimental: public browser availability requires Chrome's applicable
origin-trial setup while the API remains gated.

# Generation Config Provider-First Design

## Goal

Redesign the macOS generation config window so it can expose five first-class providers
(`OpenAI`, `Anthropic`, `Ollama`, `HuggingFace`, and `OpenAI-Compatible`) without
reintroducing the cramped UI problems from the current compact layout.

The new design must make the common path obvious:

1. pick a provider,
2. fill one shared default config for that provider,
3. choose models per capability,
4. optionally customize a capability when it should stop inheriting the provider default,
5. only expose raw JSON and custom headers inside a clearly secondary "advanced params" area.

## Current Constraints

- The current window stores one full transport config per capability.
- The current provider enum only supports `ollama`, `huggingface`, and
  `openai-compatible`.
- The current HTTP client has native request builders for `ollama` and
  `openai-compatible`, but not for native Anthropic.
- The compact AppKit window has already been tuned for smaller screens, so the new
  design should keep the visible layout shallow and avoid always-expanded multiline
  editors.

## User Decisions Locked In

- Expose exactly five providers in the UI:
  - `OpenAI`
  - `Anthropic`
  - `Ollama`
  - `HuggingFace`
  - `OpenAI-Compatible`
- Provider defaults are shared globally per provider.
- A capability may opt out of provider defaults via `Customize`.
- `Model` uses "preset + custom input" rather than free text only.
- Terminology:
  - `Default Config`
  - `Customize`
  - `Restore Default`
  - `Advanced Params`

## UX Architecture

### Window Structure

The generation config window becomes a provider-first workbench with four persistent
regions:

1. `Provider Rail`
   - Compact left rail listing the five supported providers.
   - Selecting a provider updates the default config card and the recommended model
     presets shown in capability cards.

2. `Default Config Card`
   - Top card on the right side.
   - Owns provider-level `API Key`, `Base URL`, and `Test Connection`.
   - Also displays provider-specific helper text, for example whether the provider
     normally needs an API key or what the default endpoint should be.

3. `Capability Cards`
   - Three cards: `Text Description`, `Animation Avatar`, `Code Generation`.
   - Each card always shows:
     - provider selector filtered to providers valid for that capability,
     - preset selector,
     - custom model input,
     - inheritance state (`using default config` vs `customized`).
   - Each card does not show raw auth JSON by default.

4. `Customize / Advanced Params`
   - Hidden by default inside each capability card.
   - First expansion layer is `Customize`, exposing common overrides:
     - `API Key`
     - `Base URL`
   - Second expansion layer is `Advanced Params`, exposing low-level controls:
     - custom headers
     - raw auth JSON
     - request options JSON

### Capability Provider Rules

- `Text Description`
  - `OpenAI`
  - `Anthropic`
  - `Ollama`
  - `OpenAI-Compatible`
- `Code Generation`
  - `OpenAI`
  - `Anthropic`
  - `Ollama`
  - `OpenAI-Compatible`
- `Animation Avatar`
  - `OpenAI`
  - `HuggingFace`
  - `OpenAI-Compatible`

The full five-provider rail still exists even if a single capability card filters its
provider dropdown to a smaller set.

### Provider Defaults

- `OpenAI`
  - default base URL: `https://api.openai.com/v1`
  - common auth field: `API Key`
- `Anthropic`
  - default base URL: `https://api.anthropic.com/v1`
  - common auth field: `API Key`
- `Ollama`
  - default base URL: `http://localhost:11434`
  - API key field is visually optional or hidden unless customization requires it
- `HuggingFace`
  - default base URL: `https://api-inference.huggingface.co`
  - common auth field: `API Key`
- `OpenAI-Compatible`
  - default base URL: blank
  - common auth field: `API Key`

## Data Model

The storage model changes from "one complete transport config per capability" to
"provider defaults plus per-capability selection and optional customization."

### Proposed Shape

```json
{
  "generation": {
    "provider_defaults": {
      "openai": {
        "api_key": "sk-xxx",
        "base_url": "https://api.openai.com/v1",
        "headers": {}
      },
      "anthropic": {
        "api_key": "sk-ant-xxx",
        "base_url": "https://api.anthropic.com/v1",
        "headers": {}
      }
    },
    "text_description": {
      "provider": "openai",
      "preset": "gpt-4.1-mini",
      "model": "gpt-4.1-mini",
      "customized": false,
      "custom": null,
      "options": {
        "temperature": 0.2
      }
    }
  }
}
```

### Semantics

- `provider_defaults` owns shared config per provider.
- Each capability stores:
  - chosen provider
  - chosen preset identifier
  - effective model string
  - whether the capability is customized
  - optional custom transport data when customized
  - numeric request options

### Customize Semantics

- `customized = false`
  - capability inherits provider default `API Key`, `Base URL`, and default headers
- `customized = true`
  - capability may override `API Key`, `Base URL`, headers, raw auth JSON, and options
- `Restore Default`
  - removes capability-level custom transport data
  - keeps capability provider and chosen model intact

## Migration Strategy

The app must continue to read old `generation` configs.

### Read Path

1. Load legacy capability configs if the new `provider_defaults` block is missing.
2. Group legacy values by provider.
3. Build provider defaults from the first-seen config for each provider.
4. Compare each capability against its provider default:
   - if auth/base URL matches, mark it as not customized
   - if auth/base URL differs, mark it as customized and preserve the differing values

### Write Path

- After the user saves from the redesigned window, persist the new structure only.
- The first save upgrades the config in place.

This lets existing users open the new UI without losing current working settings, while
moving the file format to a more explainable structure over time.

## Request Layer Changes

### Provider Enum

Replace the current low-level provider list with five first-class cases:

- `openai`
- `anthropic`
- `ollama`
- `huggingface`
- `openai-compatible`

### HTTP Client Behavior

- `OpenAI`
  - use OpenAI-compatible `chat/completions` transport with fixed default base URL
- `OpenAI-Compatible`
  - use the same request shape as OpenAI, but with user-supplied base URL
- `Anthropic`
  - add a native Anthropic request builder using the `messages` API
  - automatically send:
    - `x-api-key`
    - `anthropic-version`
- `Ollama`
  - keep the current `api/generate` flow
- `HuggingFace`
  - keep capability routing limited to avatar/image-oriented generation where supported

### Auth Resolution Order

For every request:

1. use capability custom transport config if `customized = true`
2. otherwise use provider default config

This priority must be explicit in code and tests.

## Model Presets

Each provider supplies a provider-aware preset list for each valid capability.

Rules:

- Presets are suggestions, not hard limits.
- A custom model input always remains available.
- Preset choice updates the model field, but the user may override it manually.
- Different capabilities may have different preset lists under the same provider.

The first implementation can hardcode curated preset arrays in AppKit code. If this grows,
the preset catalog can move into a separate config file later.

## UI States And Copy

### Capability Card States

- `Using Default Config`
  - no custom transport fields visible
- `Customized`
  - common custom transport fields visible
- `Advanced Params Expanded`
  - custom headers + raw JSON + options shown

### Copy Intent

- primary action: `Customize`
- reset action: `Restore Default`
- secondary disclosure: `Advanced Params`

This language matches the user's correction that provider divergence is customization, not
an "advanced override."

## Error Handling

- Invalid provider base URL remains a validation error.
- Invalid raw auth JSON remains a validation error, but now only inside `Advanced Params`.
- Invalid numeric options remain a validation error.
- Unsupported provider/capability combinations should be prevented in the UI rather than
  only rejected after save.
- `Test Connection` should surface provider-specific request failures clearly without
  wiping draft input.

## Testing Plan

### AppKit Window Tests

- provider rail renders all five providers
- default config card updates when provider changes
- capability cards filter providers correctly
- capability cards default to "using default config"
- `Customize` reveals common custom fields
- `Restore Default` collapses custom fields and re-inherits defaults
- `Advanced Params` remains hidden until explicitly opened

### Store / Migration Tests

- new provider-default format round-trips through save/load
- legacy format upgrades into provider defaults + customization flags
- per-capability custom config wins over provider defaults
- restoring default removes custom transport payload cleanly

### Transport Tests

- OpenAI requests use the expected auth header and path
- Anthropic requests use native `messages` payload and required headers
- OpenAI-compatible preserves custom base URL behavior
- Ollama stays unchanged

## Implementation Boundaries

- Do not re-expand the main workbench into a permanently tall form.
- Do not remove existing compact-window improvements while introducing provider-first UX.
- Do not force all low-level fields onto the common path.
- Do not block the redesign on a server-fetched model catalog; local curated presets are
  enough for the first version.

## Success Criteria

- A new user can configure OpenAI or Anthropic without touching raw JSON.
- A power user can still customize headers or auth JSON when needed.
- Small-screen readability remains better than the current generation config window.
- Existing saved configs survive migration without silent breakage.

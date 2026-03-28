# Dynamic Desktop Pet Runtime Design

Date: 2026-03-27
Status: Draft approved in terminal conversation

## Goal

Upgrade the current macOS desktop pet from a static image into a dynamic, state-aware animated character while preserving the existing Swift-native shell, pixel-theme GUI, right-click menu flow, and bottom-right desktop placement.

The first implementation target is a runtime foundation, not a full AI-driven live animation system.

## Product Direction

The desktop pet should feel notably more alive than the current static `base.png` rendering.

The accepted direction is:

1. Runtime format is always frame sequences.
2. The visual result should be "surprising enough" rather than just technically animated.
3. Animation quality should come from two layers:
   - frame-sequence character motion
   - lightweight code-driven motion enhancement
4. Randomness must stay within the current high-level state.
5. First version must support:
   - state-change-triggered animation switching
   - timer-triggered random variant switching inside the current state
6. First version does not include background generation of new animation variants while the pet is running.

## Current State

The current runtime behavior is simple:

1. `DesktopPetView` loads a single image via `PetAssetLocator.displayImageURL(...)`.
2. `PetAssetLocator` resolves one file from:
   - `<pet>/<state>/0.png`
   - `base.png`
3. `AvatarAssetStore` writes exactly one image per state:
   - `idle/0.png`
   - `working/0.png`
   - `alert/0.png`
4. No animation timeline, frame cache, variant selection, or playback metadata exists.

This means the first animated version requires a real contract change at both the asset layer and runtime layer.

## Chosen Approach

The accepted approach is:

1. Keep frame sequences as the only runtime animation format.
2. Treat video generation, if added later, as an upstream asset source only.
3. Use code animation only as a secondary enhancement layer, not as the main character-motion source.

This is preferred over direct video playback because:

1. transparent compositing is simpler and safer
2. state switching is easier to control
3. fallback to static rendering remains trivial
4. the future AI asset pipeline can normalize all outputs to the same runtime contract

## Runtime Scope For Version 1

Version 1 must support exactly three animated state groups:

1. `idle`
2. `working`
3. `alert`

Version 1 does not include:

1. lip sync
2. skeletal deformation
3. particle effects
4. live background model generation
5. cross-state random acting
6. direct runtime video playback

## Asset Contract

### Runtime Asset Format

Frame sequences become the runtime contract.

Recommended normalized layout:

```text
assets/pets/<pet_id>/
├── config.json
├── base.png
├── idle/
│   ├── main/
│   │   ├── 0.png
│   │   ├── 1.png
│   │   └── ...
│   └── blink/
│       ├── 0.png
│       └── ...
├── working/
│   ├── main/
│   └── focus/
└── alert/
    ├── main/
    └── react/
```

Each top-level state can contain one or more same-state variants.

### Backward Compatibility

Older assets remain valid:

1. `idle/0.png`
2. `working/0.png`
3. `alert/0.png`
4. `base.png`

If a state uses the legacy single-frame layout, the runtime treats it as a single-frame static animation.

### Metadata

`config.json` should be extended to describe animation playback, not just identity/persona.

Minimum animation metadata:

1. `default_variant`
2. `fps`
3. `loop_mode`

Illustrative shape:

```json
{
  "animations": {
    "idle": {
      "default_variant": "main",
      "variants": {
        "main": { "fps": 8, "loop_mode": "loop" },
        "blink": { "fps": 10, "loop_mode": "once" }
      }
    }
  }
}
```

The first implementation should stay conservative: only the fields needed by the runtime should be introduced.

## Runtime Architecture

The runtime should be split into focused units instead of expanding `DesktopPetView` further.

### 1. `PetAnimationLocator`

Responsibility:

1. resolve the active pet animation from assets
2. normalize legacy single-frame assets into the same output shape as multi-frame assets
3. return a runtime animation description, not a single image URL

Suggested output model:

1. `state`
2. `variant`
3. `frameURLs`
4. `fps`
5. `loopMode`

This is the evolution path for the current `PetAssetLocator`.

### 2. `PetAnimationPlayer`

Responsibility:

1. preload or lazily decode current animation frames
2. advance frame index on a timer
3. handle loop completion
4. reset when a new animation is selected

It must not own business state. It only plays a supplied animation description.

### 3. `PetMotionEnhancer`

Responsibility:

1. add lightweight transform-based motion on top of the rendered animation
2. provide subtle breathing/floating/tension cues per state
3. make transitions feel more alive without replacing the frame animation itself

It should operate on view or layer transforms only.

### 4. `DesktopPetView`

Responsibility after refactor:

1. subscribe to state/theme/copy changes
2. map `ShellWorkState` to `idle / working / alert`
3. request an animation from the locator
4. hand the animation to the player
5. configure the enhancer for the current state
6. continue to own hit-testing and visible status-chip behavior

`DesktopPetView` should become an orchestration layer, not the playback engine itself.

## Playback Rules

### State Mapping

State mapping remains:

1. `idle -> idle`
2. `working -> working`
3. `focus -> working`
4. `break -> alert`

This preserves current product semantics.

### Default Playback

When a state becomes active:

1. resolve that state's default variant
2. start playback from frame `0`
3. apply the corresponding motion-enhancer profile

### Random Variant Switching

Randomness is allowed only inside the current state group.

Rules:

1. no cross-state random switches
2. do not interrupt a variant before at least one full loop completes
3. variant switching must have a cooldown
4. if only one variant exists, keep looping it

### Suggested Initial FPS

Reasonable first defaults:

1. `idle`: `8 fps`
2. `working`: `10 fps`
3. `alert`: `12 fps`

These are product defaults, not hard rules. Metadata should be allowed to override them.

## Motion Enhancement Layer

The enhancement layer exists to make the pet feel premium without introducing a heavy rendering system.

First version should support only:

1. `idle`: slow breathing and tiny vertical float
2. `working`: tighter, steadier motion with less floating
3. `alert`: slightly sharper entry transition and more energetic tension
4. small synchronized transition when switching state

First version should not support:

1. per-limb deformation
2. speech mouth shapes
3. physics-driven secondary motion
4. particle systems

## Performance Strategy

The product goal is visual impact, but the app remains a desktop-resident utility.

The implementation should therefore prefer:

1. current-state frame residency over loading every frame of every state
2. optional prewarm of the next default state variant only if needed
3. no direct video decode pipeline
4. no expensive image filters in the render loop

The current static baseline observed during development was approximately:

1. `Physical footprint`: `12.4 MB`
2. `RSS`: `60.6 MB`

The animated runtime should be validated against this baseline and kept within a reasonable always-on desktop footprint.

## AI Pipeline Alignment

The runtime format decision is intentionally separated from upstream generation.

Future AI generation should be layered as:

1. `character base`
   - fixed character identity and constraints
2. `variant generation`
   - same-state animation variants for `idle / working / alert`
3. `asset normalization`
   - image or video outputs converted into frame sequences
4. `runtime playback`
   - only consumes normalized frame-sequence assets

This enables later support for:

1. image-model-generated variants
2. video-model-generated variants after frame extraction
3. user-supplied manual animation packs
4. future background generation without changing runtime playback architecture

## First Implementation Boundary

The first implementation project should be:

`dynamic desktop pet foundation`

Concretely:

1. animation-capable asset resolution
2. frame-sequence player
3. state-based switching
4. same-state timed random variant selection
5. code-based motion enhancement
6. legacy asset compatibility

It should not attempt to solve live generation at the same time.

## Validation Criteria

The implementation is acceptable only if all of the following hold:

1. legacy pets with only `base.png` or `state/0.png` still render correctly
2. multi-frame assets animate correctly for `idle / working / alert`
3. state changes immediately switch to the correct animation family
4. timer-based randomness only selects variants inside the current state
5. bottom-right window placement remains intact
6. right-click context menu and pixel-theme shell remain intact
7. status text and generated speech copy continue to work
8. runtime remains visually smooth during normal desktop use

## Risks

1. If animation metadata is made too implicit, asset compatibility will become fragile.
2. If `DesktopPetView` absorbs playback details directly, the code will become hard to evolve.
3. If frame loading is too eager, memory use may spike unnecessarily.
4. If code enhancement is too aggressive, it may visually fight the frame-sequence motion.
5. If the first version tries to include background live generation, the project scope will likely explode.

## Recommendation

Proceed with a dedicated implementation project for:

1. frame-sequence runtime support
2. same-state animated variants
3. lightweight enhancement motion
4. strict backward compatibility with current assets

This delivers a visibly dynamic pet soon, while preserving a clean path toward future AI-generated animation packs.

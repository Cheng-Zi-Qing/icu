# PRD 1.4 Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the PRD 1.4 asset pipeline and align the dependent 1.0-1.3 runtime and reporting paths around one shared builder flow and one SQLite-backed data path.

**Architecture:** Introduce one shared builder orchestration layer for CLI and UI, one runtime asset resolver that prefers action frames over `base.png`, and one SQLite-backed health data facade that becomes the primary source for reminders and reports while keeping `daily_stats.py` as a compatibility layer. Keep old assets and current UI flows working through explicit fallback behavior instead of a broad refactor.

**Tech Stack:** Python 3.11, PySide6, SQLite, Pillow, OpenCV, rembg, watchdog, pytest

---

## Preflight

Validation commands in this plan assume a Python environment with test tools installed:

```bash
python3 -m pip install -r requirements.txt -r requirements-dev.txt
```

## File Map

### New files

- `builder/pipeline.py`
  Shared builder orchestration for CLI and UI. Owns checkpoint-aware build flow, rescue flow, and dependency injection for tests.
- `src/pet_assets.py`
  Runtime asset resolver that maps ICU states to action-frame paths and falls back to `base.png`.
- `src/health_repository.py`
  SQLite-backed business facade for state transitions, reminder lifecycle, water intake, and daily/weekly summaries.
- `tests/test_builder_pipeline.py`
  Focused tests for checkpoint reuse, rescue staging, rescue completion, and packed asset output expectations.
- `tests/test_pet_assets.py`
  Tests for new asset-resolution behavior and legacy `base.png` fallback.
- `tests/test_health_repository.py`
  Tests for state, reminder, and hydration persistence through the SQLite-backed facade.
- `tests/test_reports_sqlite.py`
  Tests for daily and weekly summary generation from SQLite-backed records.

### Modified files

- `builder/builder.py`
  Replace inline orchestration with `BuilderPipeline`.
- `builder/asset_packer.py`
  Write runtime-friendly config, action directories, and a compatible `base.png`.
- `builder/vision_slicer.py`
  Expose rescue-friendly helpers or outputs needed by the shared pipeline.
- `src/avatar_wizard.py`
  Reuse the shared builder pipeline instead of hand-writing asset directories and bypassing checkpoints.
- `src/avatar_manager.py`
  Load avatars through the new asset resolver and preview selection logic.
- `src/pet_widget.py`
  Resolve displayed frames through `src/pet_assets.py`, log reminder responses through the new data facade, and generate reports from SQLite-backed summaries.
- `src/pet_main.py`
  Build weekly report input from SQLite-backed summaries instead of `daily_stats.json`.
- `src/reminder.py`
  Normalize reminder types to `eye_care` / `stretch` / `hydration` and record reminder lifecycle through the new repository.
- `src/ollama_client.py`
  Accept normalized reminder type names consistently.
- `src/database.py`
  Add any schema helpers required by the new repository while keeping existing tables compatible.
- `src/daily_stats.py`
  Convert into a compatibility facade that writes to `SQLite` first and only mirrors JSON when necessary.
- `src/report_generator.py`
  Generate daily and weekly summaries from `SQLite`.
- `src/daily_report.py`
  Consume unified summary payloads rather than raw `daily_stats.json`-shaped data.
- `src/weekly_report.py`
  Consume unified summary payloads rather than raw `daily_stats.json` week slices.

### Existing tests that may need touch-ups if behavior shifts

- `tests/test_core.py`
- `tests/test_integration.py`
- `tests/test_prd_1_3.py`

## Task 1: Shared Builder Orchestration

**Files:**
- Create: `builder/pipeline.py`
- Modify: `builder/builder.py`
- Test: `tests/test_builder_pipeline.py`

- [ ] **Step 1: Write the failing test for checkpoint-aware orchestration**

```python
def test_build_reuses_cached_persona_and_image(tmp_path):
    pipeline = BuilderPipeline(
        forge=StubForge(result={"pet_id": "capy", "display_name": "水豚", "image_generation_prompt": "prompt", "ai_persona_system_prompt": "persona", "expected_actions": ["idle", "working", "alert"]}),
        generator=StubGenerator(result=str(tmp_path / "sheet.png")),
        slicer=StubSlicer(result={"success": True, "frames": ["f1", "f2", "f3"], "actions": ["idle", "working", "alert"]}),
        packer=StubPacker(),
    )
    result = pipeline.build("一只水豚", force=False)
    assert result["asset_dir"].endswith("capy")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_builder_pipeline.py::test_build_reuses_cached_persona_and_image -q`

Expected: FAIL because `BuilderPipeline` does not exist yet.

- [ ] **Step 3: Write the minimal shared orchestration**

```python
class BuilderPipeline:
    def build(self, prompt, force=False):
        persona = self.forge.forge(prompt, force)
        image_path = self.generator.generate(persona["image_generation_prompt"], force)
        sliced = self.slicer.process(image_path, persona["expected_actions"])
        return self._pack_success(persona, sliced)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_builder_pipeline.py::test_build_reuses_cached_persona_and_image -q`

Expected: PASS

- [ ] **Step 5: Point the CLI entry at `BuilderPipeline`**

```python
def main():
    pipeline = BuilderPipeline()
    result = pipeline.build(args.prompt, force=args.force)
```

- [ ] **Step 6: Run the focused builder test file**

Run: `python3 -m pytest tests/test_builder_pipeline.py -q`

Expected: PASS for the initial orchestration tests.

- [ ] **Step 7: Commit**

```bash
git add builder/pipeline.py builder/builder.py tests/test_builder_pipeline.py
git commit -m "feat: add shared builder pipeline"
```

## Task 2: Rescue Flow and UI Pipeline Reuse

**Files:**
- Modify: `builder/pipeline.py`
- Modify: `builder/asset_packer.py`
- Modify: `builder/vision_slicer.py`
- Modify: `src/avatar_wizard.py`
- Test: `tests/test_builder_pipeline.py`

- [ ] **Step 1: Write the failing test for rescue staging**

```python
def test_failed_slice_stages_rescue_files(tmp_path):
    pipeline = make_pipeline(tmp_path, slicer_result={"success": False, "found": 1, "expected": 3, "message": "动作数量不匹配"})
    result = pipeline.build("一只树懒", force=True)
    rescue_dir = tmp_path / "_needs_rescue" / "cyber_sloth"
    assert result["status"] == "needs_rescue"
    assert (rescue_dir / "raw_sheet.png").exists()
    assert (rescue_dir / "config.json").exists()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_builder_pipeline.py::test_failed_slice_stages_rescue_files -q`

Expected: FAIL because rescue staging metadata is incomplete.

- [ ] **Step 3: Implement rescue staging in the shared pipeline**

```python
def _stage_rescue(self, persona, image_path, failure):
    rescue_dir = self.rescue_root / persona["pet_id"]
    shutil.copy(image_path, rescue_dir / "raw_sheet.png")
    json.dump({...persona, ...failure}, rescue_dir / "config.json")
```

- [ ] **Step 4: Write the failing test for rescue completion**

```python
def test_rescue_build_packs_manual_frames(tmp_path):
    rescue_dir = seed_rescue_dir(tmp_path, pet_id="cyber_sloth", actions=["idle", "working", "alert"])
    result = pipeline.rescue("cyber_sloth")
    assert result["status"] == "packed"
    assert (tmp_path / "assets" / "pets" / "cyber_sloth" / "idle" / "0.png").exists()
```

- [ ] **Step 5: Run test to verify it fails**

Run: `python3 -m pytest tests/test_builder_pipeline.py::test_rescue_build_packs_manual_frames -q`

Expected: FAIL because `rescue()` does not exist yet.

- [ ] **Step 6: Implement `rescue()` and runtime-friendly packing**

```python
def rescue(self, pet_id):
    frames, actions, persona = self._load_rescue_inputs(pet_id)
    return self._pack(persona, frames, actions)
```

`AssetPacker` must also write `base.png` from the best available frame and persist `actions` in `config.json`.

- [ ] **Step 7: Switch `AvatarWizard` to use the shared pipeline**

```python
pipeline = BuilderPipeline()
result = pipeline.build(prompt, force=False)
self.finished.emit(result)
```

Remove direct asset-directory writes from `save_avatar()` and route saves through the packer or the shared pipeline output.

- [ ] **Step 8: Run the full builder pipeline tests**

Run: `python3 -m pytest tests/test_builder_pipeline.py -q`

Expected: PASS for checkpoint, rescue staging, and rescue completion tests.

- [ ] **Step 9: Commit**

```bash
git add builder/pipeline.py builder/asset_packer.py builder/vision_slicer.py src/avatar_wizard.py tests/test_builder_pipeline.py
git commit -m "feat: close builder rescue flow and UI reuse"
```

## Task 3: Runtime Asset Resolver and Legacy Fallback

**Files:**
- Create: `src/pet_assets.py`
- Modify: `src/avatar_manager.py`
- Modify: `src/pet_widget.py`
- Test: `tests/test_pet_assets.py`

- [ ] **Step 1: Write the failing test for action-frame resolution**

```python
def test_resolve_prefers_action_frame_over_base_png(tmp_path):
    asset_dir = seed_asset_dir(tmp_path, pet_id="capy", with_actions=True, with_base=True)
    resolver = PetAssetResolver(asset_root=tmp_path / "assets" / "pets")
    assert resolver.resolve_frame("capy", "working").name == "0.png"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_pet_assets.py::test_resolve_prefers_action_frame_over_base_png -q`

Expected: FAIL because `PetAssetResolver` does not exist yet.

- [ ] **Step 3: Implement the minimal resolver**

```python
STATE_TO_ACTION = {
    "idle": "idle",
    "working": "working",
    "focus": "alert",
    "break": "alert",
    "eye_care": "alert",
    "stretch": "alert",
    "hydration": "alert",
}
```

- [ ] **Step 4: Write the failing test for legacy fallback**

```python
def test_resolve_falls_back_to_base_png_for_legacy_assets(tmp_path):
    asset_dir = seed_asset_dir(tmp_path, pet_id="seal", with_actions=False, with_base=True)
    resolver = PetAssetResolver(asset_root=tmp_path / "assets" / "pets")
    assert resolver.resolve_frame("seal", "working").name == "base.png"
```

- [ ] **Step 5: Run test to verify it fails**

Run: `python3 -m pytest tests/test_pet_assets.py::test_resolve_falls_back_to_base_png_for_legacy_assets -q`

Expected: FAIL until fallback order is implemented.

- [ ] **Step 6: Wire `AvatarManager` and `PetWidget` to the resolver**

```python
frame_path = self.assets.resolve_frame(self.pet_id, self.current_state)
pixmap = QPixmap(str(frame_path))
```

Keep `base.png` behavior as the final fallback path.

- [ ] **Step 7: Run the asset tests**

Run: `python3 -m pytest tests/test_pet_assets.py -q`

Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add src/pet_assets.py src/avatar_manager.py src/pet_widget.py tests/test_pet_assets.py
git commit -m "feat: add runtime asset resolver"
```

## Task 4: SQLite-Backed Health Repository and Compatibility Layer

**Files:**
- Create: `src/health_repository.py`
- Modify: `src/database.py`
- Modify: `src/reminder.py`
- Modify: `src/pet_widget.py`
- Modify: `src/daily_stats.py`
- Modify: `src/ollama_client.py`
- Test: `tests/test_health_repository.py`

- [ ] **Step 1: Write the failing test for normalized reminder persistence**

```python
def test_record_reminder_lifecycle_normalizes_hydration(tmp_path):
    repo = HealthRepository(Database(tmp_path / "icu.db"))
    reminder_id = repo.record_reminder_shown("hydration")
    repo.record_reminder_response(reminder_id, "completed", volume_ml=300, cup_percentage=100)
    summary = repo.get_daily_summary(date.today())
    assert summary["hydration"]["triggered"] == 1
    assert summary["hydration"]["responded"] == 1
    assert summary["hydration"]["intake_ml"] == 300
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_health_repository.py::test_record_reminder_lifecycle_normalizes_hydration -q`

Expected: FAIL because `HealthRepository` does not exist yet.

- [ ] **Step 3: Implement `HealthRepository` over `Database`**

```python
class HealthRepository:
    def record_state_transition(self, from_state, to_state, duration_seconds=0): ...
    def record_reminder_shown(self, reminder_type, focus_duration=0): ...
    def record_reminder_response(self, reminder_id, response, volume_ml=0, cup_percentage=0): ...
    def get_daily_summary(self, target_date): ...
    def get_weekly_summary(self, week_start): ...
```

- [ ] **Step 4: Update reminder emission paths to use normalized reminder types**

```python
msg = ai.generate_reminder("hydration")
reminder_id = repo.record_reminder_shown("hydration")
pet.show_bubble(msg, "hydration")
```

Replace `water` with `hydration` everywhere in active code paths.

- [ ] **Step 5: Convert `daily_stats.py` into a compatibility facade**

```python
class DailyStats:
    def get_today_stats(self):
        return self.repo.get_daily_summary(date.today())
```

Existing methods should delegate to `HealthRepository` rather than owning the truth.

- [ ] **Step 6: Run the repository tests**

Run: `python3 -m pytest tests/test_health_repository.py -q`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add src/health_repository.py src/database.py src/reminder.py src/pet_widget.py src/daily_stats.py src/ollama_client.py tests/test_health_repository.py
git commit -m "feat: move health tracking to sqlite"
```

## Task 5: SQLite-Backed Reporting and App Entry Points

**Files:**
- Modify: `src/report_generator.py`
- Modify: `src/daily_report.py`
- Modify: `src/weekly_report.py`
- Modify: `src/pet_main.py`
- Test: `tests/test_reports_sqlite.py`
- Test: `tests/test_prd_1_3.py`

- [ ] **Step 1: Write the failing test for daily summary generation**

```python
def test_generate_daily_report_uses_sqlite_summary(tmp_path):
    repo = seed_day_of_activity(tmp_path)
    report = ReportGenerator(repo.db).generate_daily_report()
    assert report["hydration"]["responded"] == 1
    assert report["work_minutes"] > 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_reports_sqlite.py::test_generate_daily_report_uses_sqlite_summary -q`

Expected: FAIL because the current report output shape is too small.

- [ ] **Step 3: Expand `ReportGenerator` to return unified daily and weekly payloads**

```python
report = {
    "work_minutes": ...,
    "focus_count": ...,
    "focus_minutes": ...,
    "break_count": ...,
    "eye_care": {...},
    "stretch": {...},
    "hydration": {...},
}
```

- [ ] **Step 4: Adapt daily and weekly dialogs to the unified payload**

```python
dialog = DailyReportDialog(report, self)
week_dialog = WeeklyReportDialog(weekly_summary, pet)
```

- [ ] **Step 5: Switch `pet_main.py` weekly report entry to the SQLite-backed weekly summary**

```python
repo = HealthRepository(Database())
week_data = repo.get_weekly_summary(current_week_start)
```

- [ ] **Step 6: Run the reporting tests**

Run: `python3 -m pytest tests/test_reports_sqlite.py tests/test_prd_1_3.py -q`

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add src/report_generator.py src/daily_report.py src/weekly_report.py src/pet_main.py tests/test_reports_sqlite.py tests/test_prd_1_3.py
git commit -m "feat: align reports with sqlite summaries"
```

## Task 6: Full Regression Pass

**Files:**
- Modify as needed: `tests/test_core.py`
- Modify as needed: `tests/test_integration.py`

- [ ] **Step 1: Run the focused closeout suite**

Run:

```bash
python3 -m pytest \
  tests/test_builder_pipeline.py \
  tests/test_pet_assets.py \
  tests/test_health_repository.py \
  tests/test_reports_sqlite.py \
  -q
```

Expected: PASS

- [ ] **Step 2: Run the legacy smoke tests that should still hold**

Run:

```bash
python3 -m pytest \
  tests/test_core.py \
  tests/test_integration.py \
  tests/test_prd_1_3.py \
  -q
```

Expected: PASS, or clear failures that identify remaining compatibility work.

- [ ] **Step 3: Fix any compatibility regressions revealed by the smoke tests**

```python
# Minimal compatibility fixes only.
```

- [ ] **Step 4: Re-run the full suite**

Run: `python3 -m pytest tests -q`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests src builder
git commit -m "test: verify PRD 1.4 closeout regression suite"
```

## Manual Review Notes

This plan intentionally keeps the change set inside one closeout track instead of splitting into separate plans because the builder flow, runtime asset loading, and SQLite reporting path are tightly coupled and must be verified together to prove the product-level closure.

Subagent plan review is normally part of the skill workflow. If subagent use is not authorized in the session, perform a manual review of this document before execution and record any changes in the plan file before starting implementation.

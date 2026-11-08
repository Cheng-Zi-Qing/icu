#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[check_native_shell] Running manual runtime tests..."
swiftc \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Copy/TextCatalog.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Copy/UserFacingErrorCopy.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Copy/CopyOverrideStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/RuntimeLaunchDiagnostics.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/ShellState.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/WindowPlacement.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/StateStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/WorkSessionController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/ReminderScheduler.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Health/HealthMetricsModels.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Health/HealthMetricsStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Health/HealthSessionTracker.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/PetAnimationModels.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/PetAssetLocator.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarAssetStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarCatalog.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarBuilderBridge.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarSettingsStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/DesktopPetCopy.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Menu/StatusItemMenuModel.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityRouter.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationSettingsStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationHTTPClient.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/SpeechDraft.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/SpeechGenerationService.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/ThemeGenerationService.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Theme/ThemeDefinition.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Theme/ThemePack.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Theme/PixelTheme.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Theme/ThemeManager.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Drag/DragPhysics.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/EdgeSnapSettings.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Edge/EdgeDockLayout.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetStrokeDetector.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetNapSchedule.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetGazeTracker.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetActionClip.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetIdleActionSchedule.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/StateStoreManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/PetBehaviorManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/AppPathsManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/DragPhysicsManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/EdgeDockManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/WorkSessionManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/MenuModelManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/GenerationSettingsManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/HealthMetricsManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/ThemePackManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/ReminderSchedulerManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/AvatarCatalogManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/AvatarAssetStoreManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/AvatarSettingsStoreManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/AvatarBuilderBridgeManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/PetAssetLocatorManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/WindowPlacementManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/ThemeGenerationManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/SpeechGenerationManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/StateStoreManualMain.swift" \
  -o "$TMP_DIR/runtime-tests"

"$TMP_DIR/runtime-tests"

echo "[check_native_shell] Running AppKit theme tests..."
swiftc -framework AppKit \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Copy/UserVisibleCopyKey.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Copy/TextCatalog.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Copy/UserFacingErrorCopy.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Copy/CopyOverrideStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/AppPaths.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/RuntimeLaunchDiagnostics.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/ShellState.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/StateStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/WorkSessionController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/WindowPlacement.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/ReminderScheduler.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Health/HealthMetricsModels.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Health/HealthMetricsStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Health/HealthSessionTracker.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Health/HealthReportWindowController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/PetAnimationModels.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/PetAssetLocator.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarCatalog.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarBuilderBridge.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarAssetStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarSettingsStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/InlineAvatarCreationModels.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/DesktopPetMenuModel.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Menu/ThemedMenuPanel.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Menu/FloatingPanelController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Menu/ContextMenuPanelController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Menu/StatusItemMenuModel.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Menu/StatusMenuPanelController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarPanelTheme.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarSelectorWindowController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Avatar/AvatarWizardWindowController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/DesktopPetCopy.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/ReminderCardView.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/PetAnimationPlayer.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/PetMotionEnhancer.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Drag/DragPhysics.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Drag/PetDragController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Drag/PetPoseSprites.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Runtime/EdgeSnapSettings.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Edge/EdgeDockLayout.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Edge/WindowSlideAnimator.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Edge/PetEdgeDockController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Edge/PetPeekFrames.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/PixelArtScaler.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Animation/AnimationCurve.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Animation/GroundShadowController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Animation/InteractionLayer.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Animation/LayerTransform.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Animation/PetAnimationEngine.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetStrokeDetector.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetNapSchedule.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetActionClip.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetIdleActionSchedule.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetBehaviorCoordinator.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetGazeTracker.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Behavior/PetGazeController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Cursor/PetCursor.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/Cursor/BackgroundCursor.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/StatusChipCell.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView+Animation.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView+Overlays.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/DesktopPetView+Cursor.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/PetPlaceholderImage.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/NSImage+AlphaSampling.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Pet/DesktopPetWindowController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityModels.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationCapabilityRouter.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationSettingsStore.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationHTTPClient.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/SpeechDraft.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/SpeechGenerationService.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/ThemeGenerationService.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationCoordinator.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Generation/GenerationConfigWindowController.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Theme/ThemeDefinition.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Theme/ThemePack.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Theme/PixelTheme.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Theme/ThemedComponents.swift" \
  "$ROOT_DIR/apps/macos-shell/Sources/ICUShell/Theme/ThemeManager.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/StateStoreManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/GenerationSettingsManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/ThemeGenerationManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/HealthReportAppKitManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/MenuPanelAppKitManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/GenerationConfigAppKitManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/PixelArtScalerAppKitManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/StatusChipAppKitManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/PetBehaviorAppKitManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/PetCursorAppKitManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/HeadlessWindows.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/HeadlessWindowsAppKitManualTests.swift" \
  "$ROOT_DIR/apps/macos-shell/Tests/ManualRuntime/ThemeAppKitManualMain.swift" \
  -o "$TMP_DIR/theme-appkit-tests"

"$TMP_DIR/theme-appkit-tests"

echo "[check_native_shell] Compiling AppKit shell..."
swiftc -framework AppKit $(find "$ROOT_DIR/apps/macos-shell/Sources/ICUShell" -name '*.swift' | sort | tr '\n' ' ') -o "$TMP_DIR/ICUShell"

echo "[check_native_shell] PASS"

# Code Quality & Refactoring Plan

## Current Issues

### Large Files (>400 lines)
1. **`audio_controls.dart` - 712 lines**
   - Contains multiple control widgets mixed together
   - Should be split into separate component files

2. **`job_list_card.dart` - 482 lines**
   - Complex job card with retry logic, menu, etc.
   - Should extract menu, status badge, actions into separate files

3. **`upload_section.dart` - 468 lines**
   - Handles both file upload and URL input
   - Metadata fetching logic mixed with UI
   - Should extract metadata service and UI components

4. **`transcription_api_service.dart` - 491 lines**
   - Multiple API endpoints in one service
   - Should split into smaller, focused services

5. **`display_settings_popover.dart` - 353 lines**
   - Large popover with multiple controls
   - Should extract individual control widgets

## Refactoring Priority

### High Priority (Do Soon)
1. **Split `audio_controls.dart`**
   ```
   widgets/audio_controls/
   ├── audio_controls.dart (main widget, ~100 lines)
   ├── playback_controls.dart (play/pause/stop/seek)
   ├── speed_control.dart
   ├── transpose_control.dart
   ├── sargam_control.dart
   ├── reference_frequency_control.dart
   └── zoom_control.dart
   ```

2. **Extract metadata fetching from `upload_section.dart`**
   ```
   services/
   └── metadata_service.dart (YouTube/URL metadata fetching)
   
   widgets/upload/
   ├── upload_section.dart (main container, ~150 lines)
   ├── file_upload_tab.dart
   ├── url_upload_tab.dart
   └── metadata_display.dart
   ```

3. **Split `job_list_card.dart`**
   ```
   widgets/job_list/
   ├── job_list_card.dart (main card, ~150 lines)
   ├── job_status_badge.dart
   ├── job_card_menu.dart
   ├── job_card_actions.dart
   └── job_metadata_display.dart
   ```

### Medium Priority (Next Sprint)
4. **Modularize `transcription_api_service.dart`**
   ```
   services/api/
   ├── transcription_api_client.dart (HTTP client setup)
   ├── job_api.dart (job endpoints)
   ├── upload_api.dart (upload endpoints)
   └── data_api.dart (pitch/chord/instrument data)
   ```

5. **Extract controls from `display_settings_popover.dart`**
   ```
   widgets/display_settings/
   ├── display_settings_popover.dart (main popover)
   ├── layer_toggle_section.dart
   ├── confidence_slider_section.dart
   └── vocal_detail_slider.dart
   ```

### Low Priority (Future)
6. **Home screen structure** - Currently uses `part` files, consider full module separation
7. **Graph renderers** - Already well-organized, minor cleanup only

## Naming & Organization Standards

### Directory Structure
- `/widgets/[feature_name]/` - Group related widgets by feature
- `/services/` - Business logic, API calls, data management
- `/utils/` - Pure functions, helpers, converters
- `/models/` - Data classes only, no logic
- `/constants/` - Shared constants (already using `graph_constants.dart`)

### File Naming
- `feature_name_widget.dart` - UI components
- `feature_service.dart` - Business logic
- `feature_utils.dart` - Helper functions
- `feature_constants.dart` - Constants

### Function Size
- Max 50 lines per function (prefer 20-30)
- Extract complex logic into private helper functions
- Use meaningful function names that describe what, not how

### Widget Size
- Max 300 lines per widget file
- Extract sub-widgets into separate files when >100 lines
- Use composition over large widget trees

## Next Steps
1. Review and approve this plan
2. Create branch: `refactor/audio-controls`
3. Implement highest priority item
4. Test thoroughly
5. Repeat for each item

## Notes
- All refactoring should maintain existing functionality
- Add tests before refactoring complex logic
- Update imports across codebase
- Keep git commits atomic (one refactor per commit)

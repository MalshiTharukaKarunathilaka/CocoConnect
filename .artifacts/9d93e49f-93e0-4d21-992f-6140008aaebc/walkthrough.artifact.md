# Walkthrough - Rich Cancel Job Dialog & Backend Integration

Implemented the rich cancellation dialog when clicking **"Cancel job"** on future days, allowing workers to select a reason, include an optional note, and submit the cancellation to the backend.

## Changes Made

### 1. Backend Service (`lib/services/worker_service.dart`)
- Updated `declineJob(int jobId, {String? reason, String? note})` to send the selected reason and optional note in the POST request body to `/api/worker/jobs/$jobId/decline`.

### 2. UI Cancellation Dialog (`lib/screens/worker_dashboard.dart`)
- Replaced the basic confirmation dialog in `_declineJob` with a rich dialog matching the design screenshots:
  - Header: Red cross-circle icon with title **"Cancel Job Completion"**.
  - Section label: **"Select why you are not confirming completion:"**
  - Radio options list (*Work not finished yet*, *Incomplete or poor quality work*, *Workers left early / did not show up*, *Payment or working hours dispute*, *Other*).
  - Optional note text box: `"Add comments or instructions for the worker..."`.
  - Bottom action buttons: **"Back"** (outline button) and **"Submit Cancel"** (red filled pill button with cross icon).

## Verification Results

### Automated Analysis
- `lib/services/worker_service.dart`: **0 Errors / 0 Warnings**
- `lib/screens/worker_dashboard.dart`: **0 Errors / 0 Warnings**

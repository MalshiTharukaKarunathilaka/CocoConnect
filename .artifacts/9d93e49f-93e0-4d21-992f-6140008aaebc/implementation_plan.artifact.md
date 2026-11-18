# Implementation Plan - Rich Cancel Job Dialog & Backend Integration

Implement a rich cancellation dialog when clicking **"Cancel job"** on future days in `WorkerDashboard`, allowing workers to select a cancellation reason, add an optional note, submit the cancellation, and send the reason and note to the backend (`WorkerService.declineJob`).

## Proposed Changes

### `lib/services`

#### [MODIFY] [worker_service.dart](file:///C:/Users/User/AndroidStudioProjects/CocoConnect/lib/services/worker_service.dart)
- Update `declineJob(int jobId, {String? reason, String? note})` to send optional `reason` and `note` in the request body to `/api/worker/jobs/$jobId/decline`.

### `lib/screens`

#### [MODIFY] [worker_dashboard.dart](file:///C:/Users/User/AndroidStudioProjects/CocoConnect/lib/screens/worker_dashboard.dart)
- Replace the simple 2-button confirmation dialog in `_declineJob(WorkerJob job)` with a rich stateful cancellation dialog matching the provided screenshots:
  - Header: Red cross-circle icon with title **"Cancel Job Completion"**.
  - Section label: **"Select why you are cancelling:"**
  - Radio options list:
    - Work not finished yet
    - Incomplete or poor quality work
    - Workers left early / did not show up
    - Payment or working hours dispute
    - Other
  - Optional note text field: `"Add comments or instructions for the worker..."`
  - Bottom action buttons: **"Back"** (outline button) and **"Submit Cancel"** (red filled pill button with cross icon).
- When submitted, call `WorkerService.declineJob(job.id, reason: selectedReason, note: noteController.text)`.

## Verification Plan

### Automated Verification
- Run `analyze_file` on `worker_dashboard.dart` and `worker_service.dart` to verify zero compilation errors.

### Manual Verification
- On the Worker Dashboard, click **"Cancel job"** on an accepted future day job.
- Verify that the rich cancellation dialog appears with radio reasons, optional note field, Back, and Submit Cancel buttons.
- Select a reason, type a note, click **"Submit Cancel"**, and verify the job is successfully cancelled and removed from the active list with a success snackbar.

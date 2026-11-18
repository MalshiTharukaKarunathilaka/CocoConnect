-- Track reason and optional note when completion is cancelled / declined by estate owner.
-- Additive and safe to run more than once.

alter table public.day_jobs
  add column if not exists completion_cancel_reason text,
  add column if not exists completion_cancel_note text,
  add column if not exists completion_cancelled_at timestamp;


-- One owner rating per accepted worker on a completed day job.
-- Additive and safe to run more than once.

alter table public.day_job_applications
  add column if not exists rating smallint,
  add column if not exists rated_at timestamp;

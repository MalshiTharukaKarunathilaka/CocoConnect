-- One worker rating for the estate owner on each accepted, completed day job.
-- Kept separate from `rating`, which is the owner's rating of the worker.
-- Additive and safe to run more than once.

alter table public.day_job_applications
  add column if not exists estate_owner_rating smallint,
  add column if not exists estate_owner_rated_at timestamp;

-- Connect worker profiles to login accounts and track applications to day jobs.
-- Additive and safe to run more than once.

create table if not exists public.worker (
  id serial primary key,
  created_at timestamptz default current_timestamp,
  worker_name json,
  job_category json,
  jobs json
);

alter table public.worker
  add column if not exists user_id integer unique references public.users(id);

create table if not exists public.day_job_applications (
  id serial primary key,
  day_job_id integer not null references public.day_jobs(id) on delete cascade,
  worker_id integer not null references public.worker(id) on delete cascade,
  status varchar not null default 'PENDING',
  created_at timestamp default current_timestamp,
  unique (day_job_id, worker_id)
);

create index if not exists day_job_applications_worker_idx
  on public.day_job_applications (worker_id, created_at desc);

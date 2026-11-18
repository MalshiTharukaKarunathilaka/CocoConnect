-- Day jobs posted by estate owners for agricultural work.
-- Additive and safe to run more than once.

create table if not exists public.day_jobs (
  id serial primary key,
  estate_owner_id integer not null references public.estate_owners(id),
  category varchar not null,
  workers_needed integer not null check (workers_needed > 0),
  required_date date not null,
  location varchar not null,
  daily_rate numeric not null check (daily_rate >= 0),
  payment_method varchar not null,
  status varchar not null default 'OPEN',
  confirmed_workers integer not null default 0
    check (confirmed_workers >= 0 and confirmed_workers <= workers_needed),
  created_at timestamp default current_timestamp
);

create index if not exists day_jobs_owner_date_idx
  on public.day_jobs (estate_owner_id, required_date, created_at desc);
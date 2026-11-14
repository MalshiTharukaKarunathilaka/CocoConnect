-- Persistent conversations between accepted day-job workers and estate owners.
-- Additive and safe to run more than once.

create table if not exists public.day_job_chats (
  id serial primary key,
  day_job_id integer not null references public.day_jobs(id) on delete cascade,
  worker_id integer not null references public.worker(id) on delete cascade,
  owner_user_id integer not null references public.users(id) on delete cascade,
  created_at timestamp default current_timestamp,
  unique (day_job_id, worker_id)
);

alter table public.day_job_chats
  add column if not exists owner_last_read_at timestamp,
  add column if not exists worker_last_read_at timestamp;

create table if not exists public.day_job_chat_messages (
  id serial primary key,
  chat_id integer not null references public.day_job_chats(id) on delete cascade,
  sender_id integer not null references public.users(id) on delete cascade,
  message text not null,
  created_at timestamp default current_timestamp
);

create index if not exists day_job_chat_messages_chat_idx
  on public.day_job_chat_messages (chat_id, created_at, id);

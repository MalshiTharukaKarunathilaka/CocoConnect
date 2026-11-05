-- Admin dashboard support: user status, dispute severity levels, region price bands.
-- Additive only. Safe to run twice.

alter table public.users
  add column if not exists status varchar default 'ACTIVE';

-- PENDING / APPROVED / REJECTED disputes can also carry a review level.
alter table public.orders
  add column if not exists dispute_severity varchar default 'medium';

create table if not exists public.region_price_bands (
  name varchar primary key,
  band varchar not null,
  updated_at timestamp default current_timestamp
);

create table if not exists public.platform_settings (
  id integer primary key default 1 check (id = 1),
  fee numeric default 2.5,
  radius integer default 3,
  language varchar default 'en',
  payment_hold integer default 4,
  support varchar default 'support@cococonnect.lk',
  updated_at timestamp default current_timestamp
);

insert into public.platform_settings (id)
values (1)
on conflict (id) do nothing;

-- Promote an account to admin (run once with a real phone):
-- update public.users set role = 'ADMIN', status = 'ACTIVE' where phone = '07XXXXXXXX';

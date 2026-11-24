-- Where each user is, picked on a map (or from GPS) at sign-up. Used to show
-- listings and buyer requests within a chosen distance.
-- Additive only: nullable columns. Safe to run twice.

alter table public.users
  add column if not exists latitude double precision;

alter table public.users
  add column if not exists longitude double precision;

-- Links each estate owner login (users) to their estate (estate_owners), so
-- listings, offers and chats belong to whoever is logged in.
-- Additive only: one nullable column. Existing estates keep user_id NULL
-- until an owner account claims them. Safe to run twice.

alter table public.estate_owners
  add column if not exists user_id integer unique references public.users(id);

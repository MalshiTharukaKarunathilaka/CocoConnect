-- Completing a deal at a different price than agreed raises a price dispute
-- for an admin to review. Until it is approved the agreed price stays in
-- delivered_price_per_unit; the requested one waits in
-- dispute_price_per_unit.
-- Additive only: nullable columns. Safe to run twice.

alter table public.orders
  add column if not exists dispute_price_per_unit numeric;

-- PENDING / APPROVED / REJECTED
alter table public.orders
  add column if not exists dispute_status varchar;

alter table public.orders
  add column if not exists dispute_note text;

alter table public.orders
  add column if not exists dispute_resolved_at timestamp;

-- Admins review disputes. Make an account an admin with, e.g.:
--   update public.users set role = 'ADMIN' where phone = '07XXXXXXXX';

-- What was actually delivered when an estate owner completes a deal. The
-- agreed figures stay in final_price_per_unit / total_value, so both the
-- original agreement and the actual fulfilment are kept.
-- Additive only: nullable columns. Safe to run twice.

alter table public.orders
  add column if not exists delivered_quantity integer;

alter table public.orders
  add column if not exists delivered_price_per_unit numeric;

alter table public.orders
  add column if not exists completed_at timestamp;

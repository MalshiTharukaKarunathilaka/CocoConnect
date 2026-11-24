ALTER TABLE fertilizer_orders
  ADD COLUMN IF NOT EXISTS receipt_confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS supplier_rating smallint CHECK (supplier_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS cancel_reason text,
  ADD COLUMN IF NOT EXISTS cancel_note text,
  ADD COLUMN IF NOT EXISTS cancelled_by integer,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

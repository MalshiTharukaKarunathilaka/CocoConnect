ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS cancel_reason text,
  ADD COLUMN IF NOT EXISTS cancel_note text,
  ADD COLUMN IF NOT EXISTS cancelled_by integer,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

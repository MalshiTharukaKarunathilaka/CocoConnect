ALTER TABLE machinery_bookings
  ADD COLUMN IF NOT EXISTS work_finished_at timestamptz,
  ADD COLUMN IF NOT EXISTS work_confirmed_at timestamptz,
  ADD COLUMN IF NOT EXISTS provider_rating smallint CHECK (provider_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS cancel_reason text,
  ADD COLUMN IF NOT EXISTS cancel_note text,
  ADD COLUMN IF NOT EXISTS cancelled_by integer,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

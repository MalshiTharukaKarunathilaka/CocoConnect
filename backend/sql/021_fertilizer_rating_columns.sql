ALTER TABLE public.fertilizer_orders
  ADD COLUMN IF NOT EXISTS land_owner_rating smallint CHECK (land_owner_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS rated_at timestamptz;

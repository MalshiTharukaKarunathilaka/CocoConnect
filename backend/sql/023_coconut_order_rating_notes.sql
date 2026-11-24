ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS buyer_rating_note text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS owner_rating_note text;

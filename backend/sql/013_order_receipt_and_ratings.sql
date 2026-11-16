-- Seller completion awaits buyer receipt confirmation. Existing completed orders stay completed.
-- Each participant may submit one 1-5 star rating after final completion.
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS seller_completed_at timestamp;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS buyer_confirmed_at timestamp;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS buyer_rating smallint CHECK (buyer_rating BETWEEN 1 AND 5);
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS owner_rating smallint CHECK (owner_rating BETWEEN 1 AND 5);
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS buyer_rated_at timestamp;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS owner_rated_at timestamp;

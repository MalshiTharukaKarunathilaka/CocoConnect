ALTER TABLE public.sell_requests
  ADD COLUMN IF NOT EXISTS payment_method varchar NOT NULL DEFAULT 'Any';

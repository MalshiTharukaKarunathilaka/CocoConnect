-- Fertilizer operational data (orders, chats, gov requests, complaints, alerts).
-- Run against Supabase so owner / supplier / CDO share one source of truth.

-- Replace an older empty stub schema if present (integer id, no place_id).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'fertilizer_orders'
      AND column_name = 'proposed_total'
  ) THEN
    DROP TABLE public.fertilizer_orders CASCADE;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS fertilizer_orders (
  id text PRIMARY KEY,
  place_id text NOT NULL,
  owner_key text NOT NULL,
  owner_user_id integer REFERENCES public.users(id) ON DELETE SET NULL,
  supplier_user_id integer REFERENCES public.users(id) ON DELETE SET NULL,
  company text NOT NULL DEFAULT '',
  agent text NOT NULL DEFAULT '',
  product text NOT NULL DEFAULT '',
  qty50 integer NOT NULL DEFAULT 0,
  price numeric NOT NULL DEFAULT 0,
  preferred_date date,
  slot text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'Pending Ack',
  message text NOT NULL DEFAULT '',
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  negotiation jsonb NOT NULL DEFAULT '[]'::jsonb,
  owner_stars integer,
  supplier_stars integer,
  owner_rate_note text NOT NULL DEFAULT '',
  supplier_rate_note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS fertilizer_orders_owner_idx
  ON fertilizer_orders (owner_key);
CREATE INDEX IF NOT EXISTS fertilizer_orders_place_idx
  ON fertilizer_orders (place_id);
CREATE INDEX IF NOT EXISTS fertilizer_orders_supplier_idx
  ON fertilizer_orders (supplier_user_id);

CREATE TABLE IF NOT EXISTS fertilizer_shop_talks (
  place_id text NOT NULL,
  owner_key text NOT NULL DEFAULT '',
  messages jsonb NOT NULL DEFAULT '[]'::jsonb,
  unread_supplier integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (place_id, owner_key)
);

CREATE TABLE IF NOT EXISTS fertilizer_gov_requests (
  id text PRIMARY KEY,
  owner_key text NOT NULL,
  owner_user_id integer REFERENCES public.users(id) ON DELETE SET NULL,
  cdo_user_id integer REFERENCES public.users(id) ON DELETE SET NULL,
  cdo_label text NOT NULL DEFAULT '',
  fertilizer text NOT NULL DEFAULT '',
  requested integer NOT NULL DEFAULT 0,
  approved integer NOT NULL DEFAULT 0,
  distributed integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'Pending Ack',
  district text NOT NULL DEFAULT '',
  request_date date,
  delivery_at timestamptz,
  preferred text NOT NULL DEFAULT '',
  outlet text NOT NULL DEFAULT 'CCB',
  estate_name text NOT NULL DEFAULT '',
  acres numeric,
  nic_copy text NOT NULL DEFAULT '',
  land_title_copy text NOT NULL DEFAULT '',
  beneficiary_name text NOT NULL DEFAULT '',
  address text NOT NULL DEFAULT '',
  phone text NOT NULL DEFAULT '',
  nic_number text NOT NULL DEFAULT '',
  land_address text NOT NULL DEFAULT '',
  deed_number text NOT NULL DEFAULT '',
  coconut_trees integer,
  coconut_saplings integer,
  annual_harvest_nuts integer,
  chat jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS fertilizer_gov_owner_idx
  ON fertilizer_gov_requests (owner_key);
CREATE INDEX IF NOT EXISTS fertilizer_gov_cdo_idx
  ON fertilizer_gov_requests (cdo_label);

CREATE TABLE IF NOT EXISTS fertilizer_complaints (
  id text PRIMARY KEY,
  owner_key text NOT NULL,
  owner_user_id integer REFERENCES public.users(id) ON DELETE SET NULL,
  category text NOT NULL DEFAULT '',
  product text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'Submitted',
  description text NOT NULL DEFAULT '',
  district text NOT NULL DEFAULT '',
  complaint_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fertilizer_alerts (
  id text PRIMARY KEY,
  audience text NOT NULL CHECK (audience IN ('owner', 'supplier', 'cdo')),
  user_id integer REFERENCES public.users(id) ON DELETE CASCADE,
  audience_key text NOT NULL DEFAULT '',
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  kind text NOT NULL DEFAULT 'info',
  order_id text,
  read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS fertilizer_alerts_audience_idx
  ON fertilizer_alerts (audience, audience_key);

ALTER TABLE fertilizer_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE fertilizer_shop_talks ENABLE ROW LEVEL SECURITY;
ALTER TABLE fertilizer_gov_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE fertilizer_complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE fertilizer_alerts ENABLE ROW LEVEL SECURITY;

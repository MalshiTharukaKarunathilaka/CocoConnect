-- Persistent orders belong to authenticated land owners and real suppliers/CDOs.
CREATE TABLE IF NOT EXISTS fertilizer_orders (
  id serial PRIMARY KEY,
  owner_user_id integer NOT NULL REFERENCES users(id),
  supplier_user_id integer NOT NULL REFERENCES users(id),
  product text NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  proposed_total numeric(14,2) NOT NULL CHECK (proposed_total >= 0),
  preferred_date date NOT NULL,
  time_slot varchar(100) NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','ACCEPTED','DELIVERED','CANCELLED')),
  application jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz,
  land_owner_rating smallint CHECK (land_owner_rating BETWEEN 1 AND 5),
  rated_at timestamptz
);
CREATE INDEX IF NOT EXISTS fertilizer_owner_orders ON fertilizer_orders(owner_user_id);
CREATE INDEX IF NOT EXISTS fertilizer_supplier_orders ON fertilizer_orders(supplier_user_id);
ALTER TABLE fertilizer_orders ENABLE ROW LEVEL SECURITY;

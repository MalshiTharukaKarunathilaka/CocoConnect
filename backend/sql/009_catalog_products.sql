-- Products the admin adds from Product Setup; the mobile app reads the active ones from GET /api/products.
-- Additive only. Safe to run twice (the backend also creates it on first use).

create table if not exists public.catalog_products (
  id serial primary key,
  code varchar not null unique,
  name varchar not null,
  category varchar not null default 'Other',
  unit varchar not null default 'item',
  min_price numeric,
  max_price numeric,
  description text,
  image_url text,
  active boolean not null default true,
  created_at timestamp default current_timestamp,
  updated_at timestamp default current_timestamp
);

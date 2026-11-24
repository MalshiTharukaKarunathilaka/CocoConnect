-- Adds login accounts and buyer negotiation.
-- Additive only: creates new tables and nullable columns. Existing tables,
-- columns and rows are left untouched, and the script is safe to run twice.

create table if not exists public.users (
  id serial primary key,
  name varchar not null,
  phone varchar not null unique,
  password_hash varchar not null,
  role varchar not null,                 -- BUYER / ESTATE_OWNER / ESTATE_MANAGER / SERVICE_PROVIDER
  location varchar,
  created_at timestamp default current_timestamp
);

alter table public.buyer_requests
  add column if not exists buyer_id integer references public.users(id);

alter table public.orders
  add column if not exists buyer_id integer references public.users(id);

create table if not exists public.negotiations (
  id serial primary key,
  listing_id integer not null references public.product_listings(id),
  buyer_id integer not null references public.users(id),
  status varchar not null default 'OPEN', -- OPEN / ACCEPTED / REJECTED
  order_id integer references public.orders(id),
  created_at timestamp default current_timestamp
);

create table if not exists public.negotiation_messages (
  id serial primary key,
  negotiation_id integer not null references public.negotiations(id),
  sender_id integer not null references public.users(id),
  message text,
  offer_price_per_unit numeric,           -- set only on counter-offers
  created_at timestamp default current_timestamp
);

-- Keep these tables (phone numbers, password hashes, chats) out of Supabase's
-- public Data API. The Express backend connects as postgres, which bypasses
-- RLS, so the app itself is unaffected.
alter table public.users                enable row level security;
alter table public.negotiations         enable row level security;
alter table public.negotiation_messages enable row level security;

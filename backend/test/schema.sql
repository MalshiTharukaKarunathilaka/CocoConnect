-- The team's existing Supabase tables, as shared on 2026-10-10. Used only to
-- build the in-memory test database; never run this against Supabase.

create table public.estate_owners (
  id serial primary key,
  name varchar not null,
  estate_name varchar not null,
  location varchar,
  total_land_area varchar,
  primary_crop varchar,
  year_established integer,
  trust_score numeric default 0.0,
  created_at timestamp default current_timestamp
);

create table public.product_listings (
  id serial primary key,
  estate_owner_id integer references public.estate_owners(id),
  product_type varchar not null,
  quantity integer not null,
  available_date date not null,
  offer_price_per_unit numeric not null,
  status varchar default 'ACTIVE',
  created_at timestamp default current_timestamp
);

create table public.buyer_requests (
  id serial primary key,
  buyer_name varchar not null,
  location varchar,
  product_type varchar not null,
  requested_quantity integer not null,
  required_date date not null,
  bidding_price_per_unit numeric not null,
  trust_score numeric,
  status varchar default 'PENDING',
  created_at timestamp default current_timestamp
);

create table public.orders (
  id serial primary key,
  listing_id integer references public.product_listings(id),
  buyer_request_id integer references public.buyer_requests(id),
  final_price_per_unit numeric,
  total_value numeric,
  status varchar default 'ACCEPTED',
  created_at timestamp default current_timestamp
);

create table public.sell_requests (
  id serial primary key,
  estate_owner_id integer not null,
  buyer_request_id integer not null,
  product_type varchar not null,
  quantity integer not null,
  seller_price_per_unit numeric not null,
  available_date date,
  status varchar default 'pending',
  created_at timestamp default current_timestamp
);

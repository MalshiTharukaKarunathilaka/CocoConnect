-- The team's machinery tables, as they are in Supabase (without the CHECK
-- constraints and identity columns pg-mem does not need). Used only to build
-- the in-memory test database; never run this against Supabase.

create table public.service_providers (
  id serial primary key,
  user_id integer not null unique references public.users(id),
  identity_number varchar not null,
  email varchar,
  category varchar not null,
  machinery_type varchar not null,
  district varchar not null,
  address text not null,
  radius_km integer not null,
  terms_accepted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.machinery (
  id serial primary key,
  provider_id integer not null references public.service_providers(id),
  name varchar not null,
  category varchar not null,
  active boolean not null default true
);

create table public.machinery_services (
  id serial primary key,
  machine_id integer not null references public.machinery(id),
  name varchar not null,
  unit varchar not null,
  rate numeric not null
);

create table public.machinery_availability (
  id serial primary key,
  machine_id integer not null references public.machinery(id),
  day date not null,
  state varchar not null,
  note text
);

create table public.machinery_bookings (
  id serial primary key,
  machine_id integer not null references public.machinery(id),
  owner_user_id integer not null references public.users(id),
  estate_name varchar not null,
  address text not null,
  latitude double precision,
  longitude double precision,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status varchar not null default 'PENDING',
  proposed_total numeric not null,
  proposed_by integer not null references public.users(id),
  offer_agreed boolean not null default false,
  agreed_total numeric,
  version integer not null default 1,
  created_at timestamptz not null default now()
);

create table public.machinery_booking_items (
  id serial primary key,
  booking_id integer not null references public.machinery_bookings(id),
  service_id integer not null references public.machinery_services(id),
  name varchar not null,
  unit varchar not null,
  quantity numeric not null,
  rate numeric not null
);

create table public.machinery_messages (
  id serial primary key,
  booking_id integer not null references public.machinery_bookings(id),
  sender_id integer not null references public.users(id),
  message text not null,
  offer_total numeric,
  created_at timestamptz not null default now()
);

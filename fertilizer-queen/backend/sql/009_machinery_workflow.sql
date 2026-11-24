-- Machinery workflow tables. Review and approve before applying to hosted Supabase.
-- Additive only; existing users, marketplace, day jobs and provider profiles remain.
CREATE TABLE IF NOT EXISTS machinery (
  id serial PRIMARY KEY,
  provider_id integer NOT NULL REFERENCES service_providers(id),
  name varchar(120) NOT NULL,
  category varchar(30) NOT NULL CHECK (category IN ('Tractor','Backhoe','Hand Tractor')),
  active boolean NOT NULL DEFAULT true,
  UNIQUE (provider_id, name)
);
CREATE TABLE IF NOT EXISTS machinery_services (
  id serial PRIMARY KEY,
  machine_id integer NOT NULL REFERENCES machinery(id),
  name varchar(80) NOT NULL,
  unit varchar(10) NOT NULL CHECK (unit IN ('acre','hour','day')),
  rate numeric(14,2) NOT NULL CHECK (rate > 0),
  UNIQUE (machine_id, name)
);
CREATE TABLE IF NOT EXISTS machinery_availability (
  id serial PRIMARY KEY,
  machine_id integer NOT NULL REFERENCES machinery(id),
  day date NOT NULL,
  state varchar(20) NOT NULL CHECK (state IN ('AVAILABLE','UNAVAILABLE','MAINTENANCE')),
  note text,
  UNIQUE (machine_id, day)
);
CREATE TABLE IF NOT EXISTS machinery_bookings (
  id serial PRIMARY KEY,
  machine_id integer NOT NULL REFERENCES machinery(id),
  owner_user_id integer NOT NULL REFERENCES users(id),
  estate_name varchar(160) NOT NULL,
  address text NOT NULL,
  latitude double precision,
  longitude double precision,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','CONFIRMED','DECLINED','CANCELLED')),
  proposed_total numeric(14,2) NOT NULL CHECK (proposed_total > 0),
  proposed_by integer NOT NULL REFERENCES users(id),
  offer_agreed boolean NOT NULL DEFAULT false,
  agreed_total numeric(14,2),
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at)
);
CREATE TABLE IF NOT EXISTS machinery_booking_items (
  id serial PRIMARY KEY,
  booking_id integer NOT NULL REFERENCES machinery_bookings(id),
  service_id integer NOT NULL REFERENCES machinery_services(id),
  name varchar(80) NOT NULL,
  unit varchar(10) NOT NULL,
  quantity numeric(12,2) NOT NULL CHECK (quantity > 0),
  rate numeric(14,2) NOT NULL CHECK (rate > 0),
  UNIQUE (booking_id, service_id)
);
CREATE TABLE IF NOT EXISTS machinery_messages (
  id serial PRIMARY KEY,
  booking_id integer NOT NULL REFERENCES machinery_bookings(id),
  sender_id integer NOT NULL REFERENCES users(id),
  message text NOT NULL,
  offer_total numeric(14,2),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS machinery_booking_calendar ON machinery_bookings(machine_id, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS machinery_booking_owner ON machinery_bookings(owner_user_id);
CREATE INDEX IF NOT EXISTS machinery_message_history ON machinery_messages(booking_id, id);
ALTER TABLE machinery ENABLE ROW LEVEL SECURITY;
ALTER TABLE machinery_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE machinery_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE machinery_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE machinery_booking_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE machinery_messages ENABLE ROW LEVEL SECURITY;
-- Existing registration identifies one primary machine type. Create its first
-- inventory record, without inventing service prices or booking data.
INSERT INTO machinery(provider_id, name, category)
SELECT id, machinery_type, machinery_type FROM service_providers
WHERE machinery_type IN ('Tractor','Backhoe','Hand Tractor')
ON CONFLICT (provider_id,name) DO NOTHING;

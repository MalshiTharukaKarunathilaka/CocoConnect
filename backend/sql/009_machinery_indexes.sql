-- Machinery already has its tables (service_providers, machinery,
-- machinery_services, machinery_availability, machinery_bookings,
-- machinery_booking_items, machinery_messages). This only adds indexes so the
-- machinery map, calendar and My Bookings stay quick as bookings grow.
-- Additive only: no table, column or row is changed. Safe to run twice.

create index if not exists machinery_bookings_machine_start_idx
  on public.machinery_bookings (machine_id, starts_at);

create index if not exists machinery_bookings_owner_idx
  on public.machinery_bookings (owner_user_id, starts_at);

create index if not exists machinery_booking_items_booking_idx
  on public.machinery_booking_items (booking_id);

create index if not exists machinery_booking_items_service_idx
  on public.machinery_booking_items (service_id);

create index if not exists machinery_messages_booking_idx
  on public.machinery_messages (booking_id, created_at);

create index if not exists machinery_services_machine_idx
  on public.machinery_services (machine_id);

create index if not exists machinery_availability_machine_day_idx
  on public.machinery_availability (machine_id, day);

-- Removes everything demo_machinery_add.sql added, and nothing else.
-- It only touches the demo providers (phones 0700910001 to 0700910010), their
-- machines, services, blocked days and any bookings made on those machines.
-- Real providers and their machines are never affected.
-- Paste the whole file into the Supabase SQL Editor and run it.

delete from machinery_messages
where booking_id in (
  select b.id from machinery_bookings b
  join machinery m on m.id = b.machine_id
  join service_providers sp on sp.id = m.provider_id
  join users u on u.id = sp.user_id
  where u.phone between '0700910001' and '0700910010');

delete from machinery_booking_items
where booking_id in (
  select b.id from machinery_bookings b
  join machinery m on m.id = b.machine_id
  join service_providers sp on sp.id = m.provider_id
  join users u on u.id = sp.user_id
  where u.phone between '0700910001' and '0700910010');

delete from machinery_bookings
where machine_id in (
  select m.id from machinery m
  join service_providers sp on sp.id = m.provider_id
  join users u on u.id = sp.user_id
  where u.phone between '0700910001' and '0700910010');

delete from machinery_availability
where machine_id in (
  select m.id from machinery m
  join service_providers sp on sp.id = m.provider_id
  join users u on u.id = sp.user_id
  where u.phone between '0700910001' and '0700910010');

delete from machinery_services
where machine_id in (
  select m.id from machinery m
  join service_providers sp on sp.id = m.provider_id
  join users u on u.id = sp.user_id
  where u.phone between '0700910001' and '0700910010');

delete from machinery
where provider_id in (
  select sp.id from service_providers sp
  join users u on u.id = sp.user_id
  where u.phone between '0700910001' and '0700910010');

delete from service_providers
where user_id in (select id from users where phone between '0700910001' and '0700910010');

delete from users
where phone between '0700910001' and '0700910010';

-- Check: should now list only the real machines
select m.id, m.name, u.name as provider
from machinery m
join service_providers sp on sp.id = m.provider_id
join users u on u.id = sp.user_id
order by m.id;

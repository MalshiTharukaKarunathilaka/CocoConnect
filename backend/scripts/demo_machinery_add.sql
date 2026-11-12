-- Adds 10 demo machines around Kurunegala (4 tractors, 3 hand tractors, 3 backhoes)
-- to the real database, each with its own made-up business as the provider.
-- Paste the whole file into the Supabase SQL Editor and run it.
--
--  * Safe to run twice: anything already there is skipped.
--  * Only adds rows. Nothing existing is changed or deleted, and the two real
--    machines are not touched.
--  * The provider accounts use phones 0700910001 to 0700910010 and cannot be
--    used to log in. demo_machinery_remove.sql takes all of it out again.
--  * A machine shows on the map where its provider's login is, so each demo
--    provider has its own spot (within about 15 km of Kurunegala town).

-- 1. The provider logins ------------------------------------------------------
insert into users (name, phone, password_hash, role, location, latitude, longitude)
select v.provider, v.phone, '!demo-provider-cannot-log-in', 'SERVICE_PROVIDER', v.district, v.lat, v.lng
from (values
  ('Wijaya Agro Services',             '0700910001', 'Kurunegala',  7.5043, 80.3867),
  ('Lakmal Farm Mechanization',        '0700910002', 'Mallawapitiya', 7.4623, 80.3957),
  ('Dambokka Agro Traders',            '0700910003', 'Kurunegala',  7.5213, 80.3457),
  ('Ruwan Tractor Service',            '0700910004', 'Kurunegala',  7.4453, 80.3367),
  ('Nilanka Agro Services',            '0700910005', 'Kurunegala',  7.5133, 80.3687),
  ('Perera Farm Tools',                '0700910006', 'Kurunegala',  7.4733, 80.3287),
  ('Green Field Implements',           '0700910007', 'Ibbagamuwa',  7.5313, 80.4087),
  ('Kithsiri Earthmovers',             '0700910008', 'Kurunegala',  7.4923, 80.3217),
  ('Lanka Excavations',                '0700910009', 'Kurunegala',  7.4343, 80.3737),
  ('Rathnayake Construction & Earthworks', '0700910010', 'Ibbagamuwa', 7.5253, 80.4107)
) as v(provider, phone, district, lat, lng)
where v.phone not in (select phone from users);

-- 2. Their provider profiles (they serve within 25 km of where they are based)
insert into service_providers (user_id, identity_number, category, machinery_type, district, address, radius_km)
select u.id, 'DEMO-' || v.phone, 'Machinery', v.category, v.district, v.district, 25
from users u
join (values
  ('0700910001', 'Tractor',      'Kurunegala'),
  ('0700910002', 'Tractor',      'Kurunegala'),
  ('0700910003', 'Tractor',      'Kurunegala'),
  ('0700910004', 'Tractor',      'Kurunegala'),
  ('0700910005', 'Hand Tractor', 'Kurunegala'),
  ('0700910006', 'Hand Tractor', 'Kurunegala'),
  ('0700910007', 'Hand Tractor', 'Kurunegala'),
  ('0700910008', 'Backhoe',      'Kurunegala'),
  ('0700910009', 'Backhoe',      'Kurunegala'),
  ('0700910010', 'Backhoe',      'Kurunegala')
) as v(phone, category, district) on v.phone = u.phone
where u.id not in (select user_id from service_providers);

-- 3. One machine for each provider --------------------------------------------
insert into machinery (provider_id, name, category, active)
select sp.id, v.machine, v.category, true
from service_providers sp
join users u on u.id = sp.user_id
join (values
  ('0700910001', 'Massey Ferguson 240',   'Tractor'),
  ('0700910002', 'Kubota M6040 4WD',      'Tractor'),
  ('0700910003', 'Mahindra 575 DI',       'Tractor'),
  ('0700910004', 'Swaraj 744 FE',         'Tractor'),
  ('0700910005', 'Kubota Power Tiller',   'Hand Tractor'),
  ('0700910006', 'Yanmar 2-Wheel Tractor', 'Hand Tractor'),
  ('0700910007', 'Kubota Mini Tiller',    'Hand Tractor'),
  ('0700910008', 'JCB 3CX',               'Backhoe'),
  ('0700910009', 'CAT 424B',              'Backhoe'),
  ('0700910010', 'JCB 3DX',               'Backhoe')
) as v(phone, machine, category) on v.phone = u.phone
where (sp.id::text || '|' || v.machine) not in (select provider_id::text || '|' || name from machinery);

-- 4. What each machine does, and its rate -------------------------------------
-- The first service of each machine is the price shown on the map.
insert into machinery_services (machine_id, name, unit, rate)
select m.id, s.service, s.unit, s.rate
from machinery m
join service_providers sp on sp.id = m.provider_id
join users u on u.id = sp.user_id
join (values
  ('0700910001', 'Slasher',                 'acre', 5000),
  ('0700910001', 'Disc Ploughing',          'acre', 7000),
  ('0700910001', 'Rotary Tiller',           'acre', 6000),
  ('0700910002', 'Slasher',                 'acre', 4800),
  ('0700910002', 'Coconut Haulage Trailer', 'day',  14000),
  ('0700910003', 'Koku Nagula',             'acre', 4500),
  ('0700910003', 'Rotary Tiller',           'acre', 5500),
  ('0700910004', 'Disc Ploughing',          'acre', 6800),
  ('0700910004', 'Coconut Haulage Trailer', 'day',  13000),
  ('0700910005', 'Weeding',                 'acre', 3200),
  ('0700910005', 'Inter-row Tilling',       'acre', 3000),
  ('0700910005', 'Small Trailer Haulage',   'day',  9000),
  ('0700910006', 'Inter-row Tilling',       'acre', 3000),
  ('0700910006', 'Small Trailer Haulage',   'day',  8500),
  ('0700910007', 'Weeding',                 'acre', 3000),
  ('0700910007', 'Inter-row Tilling',       'acre', 2800),
  ('0700910008', 'Ditch & Drainage',        'hour', 4200),
  ('0700910008', 'Pit Digging',             'hour', 4200),
  ('0700910009', 'Ditch & Drainage',        'hour', 6000),
  ('0700910009', 'Land Clearing',           'hour', 6500),
  ('0700910010', 'Pit Digging',             'hour', 4500),
  ('0700910010', 'Land Clearing',           'hour', 6800)
) as s(phone, service, unit, rate) on s.phone = u.phone
where (m.id::text || '|' || s.service) not in (select machine_id::text || '|' || name from machinery_services);

-- 5. Check: should list the 10 demo machines (plus the real ones) -------------
select m.id, m.name, m.category, u.name as provider, u.latitude, u.longitude, count(s.id) as services
from machinery m
join service_providers sp on sp.id = m.provider_id
join users u on u.id = sp.user_id
left join machinery_services s on s.machine_id = m.id
group by m.id, m.name, m.category, u.name, u.latitude, u.longitude
order by m.id;

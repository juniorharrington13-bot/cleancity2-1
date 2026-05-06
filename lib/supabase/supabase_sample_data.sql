CREATE OR REPLACE FUNCTION insert_user_to_auth(
    email text,
    password text
) RETURNS UUID AS $$
DECLARE
  user_id uuid;
  encrypted_pw text;
BEGIN
  user_id := gen_random_uuid();
  encrypted_pw := crypt(password, gen_salt('bf'));
  
  INSERT INTO auth.users
    (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
  VALUES
    (gen_random_uuid(), user_id, 'authenticated', 'authenticated', email, encrypted_pw, '2023-05-03 19:41:43.585805+00', '2023-04-22 13:10:03.275387+00', '2023-04-22 13:10:31.458239+00', '{"provider":"email","providers":["email"]}', '{}', '2023-05-03 19:41:43.580424+00', '2023-05-03 19:41:43.585948+00', '', '', '', '');
  
  INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  VALUES
    (gen_random_uuid(), user_id, format('{"sub":"%s","email":"%s"}', user_id::text, email)::jsonb, 'email', '2023-05-03 19:41:43.582456+00', '2023-05-03 19:41:43.582497+00', '2023-05-03 19:41:43.582497+00');
  
  RETURN user_id;
END;
$$ LANGUAGE plpgsql;


-- Disable RLS for data insertion
SET row_level_security.active = OFF;

-- Insert the existing user CleanCityCm@gmail.com into auth.users and public.users
-- This user is assumed to already exist in auth.users and public.users,
-- so we only need to ensure its public.users record is correctly referenced.
-- For the purpose of this script, we'll ensure it exists and get its ID.
-- If it truly pre-exists, the insert into public.users might fail if not handled carefully,
-- but the prompt implies it's already there and we should reference it.
-- Let's assume the `insert_user_to_auth` function is idempotent or we're just getting the ID.

-- First, ensure the CleanCityCm@gmail.com user exists in auth.users and get its ID.
-- We'll use a CTE to store the ID for subsequent inserts.
WITH existing_user_id AS (
    SELECT insert_user_to_auth('CleanCityCm@gmail.com', 'password123') AS id
)
-- Insert or update the public.users record for CleanCityCm@gmail.com
-- We use ON CONFLICT to handle cases where the user might already exist in public.users
INSERT INTO public.users (id, email, full_name, phone_e164, role, preferred_language)
SELECT
    (SELECT id FROM existing_user_id),
    'CleanCityCm@gmail.com',
    'CleanCity Admin',
    '+237699000000',
    'admin',
    'en'
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    phone_e164 = EXCLUDED.phone_e164,
    role = EXCLUDED.role,
    preferred_language = EXCLUDED.preferred_language,
    updated_at = now();

-- Create additional users for different roles
-- Generator 1
WITH new_auth_user AS (
    SELECT insert_user_to_auth('generator1@example.com', 'password123') AS id
)
INSERT INTO public.users (id, email, full_name, phone_e164, role, preferred_language)
SELECT
    (SELECT id FROM new_auth_user),
    'generator1@example.com',
    'Alice Dupont',
    '+237677111111',
    'generator',
    'fr';

-- Generator 2
WITH new_auth_user AS (
    SELECT insert_user_to_auth('generator2@example.com', 'password123') AS id
)
INSERT INTO public.users (id, email, full_name, phone_e164, role, preferred_language)
SELECT
    (SELECT id FROM new_auth_user),
    'generator2@example.com',
    'Bob Martin',
    '+237688222222',
    'generator',
    'en';

-- Collector 1
WITH new_auth_user AS (
    SELECT insert_user_to_auth('collector1@example.com', 'password123') AS id
)
INSERT INTO public.users (id, email, full_name, phone_e164, role, preferred_language)
SELECT
    (SELECT id FROM new_auth_user),
    'collector1@example.com',
    'Charles Eto''o',
    '+237699333333',
    'collector',
    'fr';

-- Collector 2
WITH new_auth_user AS (
    SELECT insert_user_to_auth('collector2@example.com', 'password123') AS id
)
INSERT INTO public.users (id, email, full_name, phone_e164, role, preferred_language)
SELECT
    (SELECT id FROM new_auth_user),
    'collector2@example.com',
    'Diana Mboua',
    '+237677444444',
    'collector',
    'en';

-- Center 1
WITH new_auth_user AS (
    SELECT insert_user_to_auth('center1@example.com', 'password123') AS id
)
INSERT INTO public.users (id, email, full_name, phone_e164, role, preferred_language)
SELECT
    (SELECT id FROM new_auth_user),
    'center1@example.com',
    'Eco-Center Yaounde',
    '+237688555555',
    'center',
    'fr';

-- Insert Addresses
INSERT INTO public.addresses (id, user_id, label, city, neighborhood, details, latitude, longitude)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator1@example.com'),
    'Home',
    'Yaounde',
    'Melen',
    'Rue 123, Immeuble A',
    3.866667,
    11.516667;

INSERT INTO public.addresses (id, user_id, label, city, neighborhood, details, latitude, longitude)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator1@example.com'),
    'Office',
    'Yaounde',
    'Nlongkak',
    'Bâtiment B, 4ème étage',
    3.883333,
    11.516667;

INSERT INTO public.addresses (id, user_id, label, city, neighborhood, details, latitude, longitude)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator2@example.com'),
    'Apartment',
    'Douala',
    'Bonanjo',
    'Avenue de la Liberté, Apt 5',
    4.050000,
    9.700000;

INSERT INTO public.addresses (id, user_id, label, city, neighborhood, details, latitude, longitude)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'collector1@example.com'),
    'Depot',
    'Yaounde',
    'Mokolo',
    'Près du marché',
    3.866667,
    11.500000;

INSERT INTO public.addresses (id, user_id, label, city, neighborhood, details, latitude, longitude)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'center1@example.com'),
    'Main Center',
    'Yaounde',
    'Nsam',
    'Zone Industrielle',
    3.833333,
    11.550000;

-- Insert Waste Requests
-- Request 1 (Pending)
INSERT INTO public.waste_requests (id, generator_id, address_id, waste_type, quantity_estimate_kg, notes, status, scheduled_at)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator1@example.com'),
    (SELECT id FROM public.addresses WHERE user_id = (SELECT id FROM public.users WHERE email = 'generator1@example.com') AND label = 'Home'),
    'plastic',
    5.50,
    'Please pick up after 2 PM.',
    'pending',
    now() + interval '2 days';

-- Request 2 (Accepted)
INSERT INTO public.waste_requests (id, generator_id, address_id, waste_type, quantity_estimate_kg, notes, status, scheduled_at)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator2@example.com'),
    (SELECT id FROM public.addresses WHERE user_id = (SELECT id FROM public.users WHERE email = 'generator2@example.com') AND label = 'Apartment'),
    'mixed',
    12.00,
    'Large bags, need two people.',
    'accepted',
    now() + interval '1 day';

-- Request 3 (Collected)
INSERT INTO public.waste_requests (id, generator_id, address_id, waste_type, quantity_estimate_kg, notes, status, scheduled_at)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator1@example.com'),
    (SELECT id FROM public.addresses WHERE user_id = (SELECT id FROM public.users WHERE email = 'generator1@example.com') AND label = 'Office'),
    'paper',
    8.20,
    'Boxes of old documents.',
    'collected',
    now() - interval '1 day';

-- Request 4 (Delivered)
INSERT INTO public.waste_requests (id, generator_id, address_id, waste_type, quantity_estimate_kg, notes, status, scheduled_at)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator2@example.com'),
    (SELECT id FROM public.addresses WHERE user_id = (SELECT id FROM public.users WHERE email = 'generator2@example.com') AND label = 'Apartment'),
    'glass',
    3.00,
    'Bottles, handle with care.',
    'delivered',
    now() - interval '3 days';

-- Request 5 (Cancelled)
INSERT INTO public.waste_requests (id, generator_id, address_id, waste_type, quantity_estimate_kg, notes, status, scheduled_at)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator1@example.com'),
    (SELECT id FROM public.addresses WHERE user_id = (SELECT id FROM public.users WHERE email = 'generator1@example.com') AND label = 'Home'),
    'ewaste',
    2.50,
    'Old laptop and phone.',
    'cancelled',
    now() + interval '4 days';

-- Insert Pickups
-- Pickup for Request 2 (Accepted)
INSERT INTO public.pickups (id, request_id, collector_id, accepted_at)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.waste_requests WHERE generator_id = (SELECT id FROM public.users WHERE email = 'generator2@example.com') AND status = 'accepted' LIMIT 1),
    (SELECT id FROM public.users WHERE email = 'collector1@example.com'),
    now() - interval '1 hour';

-- Pickup for Request 3 (Collected)
INSERT INTO public.pickups (id, request_id, collector_id, accepted_at, collected_at)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.waste_requests WHERE generator_id = (SELECT id FROM public.users WHERE email = 'generator1@example.com') AND status = 'collected' LIMIT 1),
    (SELECT id FROM public.users WHERE email = 'collector2@example.com'),
    now() - interval '2 days',
    now() - interval '1 day';

-- Pickup for Request 4 (Delivered)
INSERT INTO public.pickups (id, request_id, collector_id, accepted_at, collected_at, delivered_at)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.waste_requests WHERE generator_id = (SELECT id FROM public.users WHERE email = 'generator2@example.com') AND status = 'delivered' LIMIT 1),
    (SELECT id FROM public.users WHERE email = 'collector1@example.com'),
    now() - interval '4 days',
    now() - interval '3 days 6 hours',
    now() - interval '3 days';

-- Insert Processing Events
-- Processing for Request 3 (Collected)
INSERT INTO public.processing_events (id, request_id, center_id, received_at, weighed_kg, accepted, notes)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.waste_requests WHERE generator_id = (SELECT id FROM public.users WHERE email = 'generator1@example.com') AND status = 'collected' LIMIT 1),
    (SELECT id FROM public.users WHERE email = 'center1@example.com'),
    now() - interval '1 day' + interval '2 hours',
    8.00,
    true,
    'Paper quality good for recycling.';

-- Processing for Request 4 (Delivered)
INSERT INTO public.processing_events (id, request_id, center_id, received_at, weighed_kg, accepted, notes)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.waste_requests WHERE generator_id = (SELECT id FROM public.users WHERE email = 'generator2@example.com') AND status = 'delivered' LIMIT 1),
    (SELECT id FROM public.users WHERE email = 'center1@example.com'),
    now() - interval '3 days' + interval '1 hour',
    2.80,
    true,
    'Glass sorted by color.';

-- Insert Eco Transactions
-- Transaction for Generator 1 (Request 3)
INSERT INTO public.eco_transactions (id, user_id, request_id, points, reason)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator1@example.com'),
    (SELECT id FROM public.waste_requests WHERE generator_id = (SELECT id FROM public.users WHERE email = 'generator1@example.com') AND status = 'collected' LIMIT 1),
    80,
    'waste_pickup';

-- Transaction for Collector 2 (Request 3)
INSERT INTO public.eco_transactions (id, user_id, request_id, points, reason)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'collector2@example.com'),
    (SELECT id FROM public.waste_requests WHERE generator_id = (SELECT id FROM public.users WHERE email = 'generator1@example.com') AND status = 'collected' LIMIT 1),
    40,
    'pickup_completion';

-- Transaction for Generator 2 (Request 4)
INSERT INTO public.eco_transactions (id, user_id, request_id, points, reason)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'generator2@example.com'),
    (SELECT id FROM public.waste_requests WHERE generator_id = (SELECT id FROM public.users WHERE email = 'generator2@example.com') AND status = 'delivered' LIMIT 1),
    30,
    'waste_pickup';

-- Transaction for Collector 1 (Request 4)
INSERT INTO public.eco_transactions (id, user_id, request_id, points, reason)
SELECT
    gen_random_uuid(),
    (SELECT id FROM public.users WHERE email = 'collector1@example.com'),
    (SELECT id FROM public.waste_requests WHERE generator_id = (SELECT id FROM public.users WHERE email = 'generator2@example.com') AND status = 'delivered' LIMIT 1),
    15,
-- Machinery is added through the provider calendar after registration.
-- Keep existing legacy machinery selections, but allow new profiles without one.
ALTER TABLE service_providers ALTER COLUMN machinery_type DROP NOT NULL;

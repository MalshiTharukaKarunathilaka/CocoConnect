-- Production concurrency protection. pg-mem cannot emulate this constraint;
-- its test loader skips this file. Apply after 009 in real PostgreSQL.
CREATE EXTENSION IF NOT EXISTS btree_gist;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'machinery_no_overlapping_confirmed') THEN
    ALTER TABLE machinery_bookings ADD CONSTRAINT machinery_no_overlapping_confirmed
      EXCLUDE USING gist (machine_id WITH =, tstzrange(starts_at, ends_at, '[)') WITH &&)
      WHERE (status = 'CONFIRMED');
  END IF;
END $$;

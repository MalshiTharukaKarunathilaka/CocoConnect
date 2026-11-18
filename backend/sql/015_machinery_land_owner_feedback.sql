-- A provider confirms completed work and rates the land owner once per booking.
CREATE TABLE IF NOT EXISTS machinery_booking_feedback (
  booking_id integer PRIMARY KEY REFERENCES machinery_bookings(id),
  owner_user_id integer NOT NULL REFERENCES users(id),
  provider_user_id integer NOT NULL REFERENCES users(id),
  rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  completed_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS machinery_feedback_owner ON machinery_booking_feedback(owner_user_id);
ALTER TABLE machinery_booking_feedback ENABLE ROW LEVEL SECURITY;

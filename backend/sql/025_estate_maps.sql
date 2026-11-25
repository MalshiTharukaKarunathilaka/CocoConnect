-- The estate map a land owner draws in the app: the real shape of the land
-- and every tree, invasive plant and pest they mark on it.
-- One row per owner. The whole map is one document so the app can save and
-- restore it in a single call; the admin dashboard summaries can read the
-- same rows later.
CREATE TABLE IF NOT EXISTS estate_maps (
  user_id integer PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  plan jsonb,
  marks jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fertilizer_supplier_messages (
  id serial PRIMARY KEY,
  owner_user_id integer NOT NULL REFERENCES users(id),
  supplier_user_id integer NOT NULL REFERENCES users(id),
  sender_user_id integer NOT NULL REFERENCES users(id),
  message varchar(2000) NOT NULL CHECK (message <> ''),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (sender_user_id = owner_user_id OR sender_user_id = supplier_user_id)
);

CREATE INDEX IF NOT EXISTS fertilizer_supplier_message_thread
  ON fertilizer_supplier_messages(owner_user_id, supplier_user_id, id);
CREATE INDEX IF NOT EXISTS fertilizer_supplier_message_inbox
  ON fertilizer_supplier_messages(supplier_user_id, id);

ALTER TABLE fertilizer_supplier_messages ENABLE ROW LEVEL SECURITY;

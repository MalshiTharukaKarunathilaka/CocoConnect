-- WhatsApp-style chats: each price offer is answered on its own card
-- (Accept Deal / Reject by the other side), and each side's last visit is
-- kept so chats can show unread counts.
-- Additive only: nullable columns. Safe to run twice.

-- PENDING / ACCEPTED / REJECTED / SUPERSEDED (a newer offer replaced it).
alter table public.negotiation_messages
  add column if not exists offer_status varchar;

alter table public.negotiations
  add column if not exists buyer_last_read_at timestamp;

alter table public.negotiations
  add column if not exists owner_last_read_at timestamp;

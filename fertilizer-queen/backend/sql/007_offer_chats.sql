-- An estate owner's offer on a buyer request opens a chat with the buyer,
-- so they can negotiate it like a listing. The chat runs on a private
-- listing (status 'OFFER', never shown in the marketplace) and remembers
-- which offer it came from.
-- Additive only: a nullable column. Safe to run twice.

alter table public.negotiations
  add column if not exists sell_request_id integer references public.sell_requests(id);

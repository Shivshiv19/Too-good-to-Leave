-- =============================================================================
-- Too Good To Leave — shared Supabase schema
-- =============================================================================
-- Single source of truth for both apps (customer app: surplus_marketplace,
-- root of this repo; shop app: too_good_to_leave_shop, shop/). Designed from
-- the actual Dart domain models on both sides, reconciling where they
-- diverge (see the comments on `bags` and `orders` below).
--
-- Money is always integer paise + a currency code, matching core/domain/
-- money.dart on both sides. Timestamps are timestamptz throughout.
--
-- Phase 1 goal: bags and orders sync live between the two apps (Realtime,
-- enabled at the bottom of this file). Payments/refunds stay minimally
-- modelled — the apps use hardcoded OTP and a fake payment gateway for now,
-- so those tables exist for shape/future use but don't need real gateway
-- wiring yet.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------

create type dietary_envelope as enum ('pure_veg', 'contains_egg', 'non_veg', 'jain');

-- Superset of the customer app's 5-value BagStatus and the shop app's
-- 3-value one (draft/live/paused). The shop app's UI only ever sets
-- draft/live/paused; sold_out/window_closed/withdrawn_by_merchant are
-- system-derived states the customer-facing side reads.
create type bag_status as enum (
  'draft', 'live', 'paused', 'sold_out', 'window_closed', 'withdrawn_by_merchant'
);

-- Superset of the customer app's 8-value OrderStatus. The shop app's
-- simpler 4-value view (reserved/collected/expired/cancelled) is a
-- *derived* mapping in shop-side code, not a separate column:
--   pending_payment, confirmed, payment_failed, ready_for_pickup -> "reserved"
--   cancelled_by_customer, cancelled_by_merchant                -> "cancelled"
--   expired_uncollected                                         -> "expired"
--   collected                                                   -> "collected"
create type order_status as enum (
  'pending_payment', 'confirmed', 'payment_failed', 'ready_for_pickup',
  'collected', 'cancelled_by_customer', 'cancelled_by_merchant', 'expired_uncollected'
);

create type payment_method as enum ('upi', 'card', 'net_banking', 'wallet');

create type payment_status as enum (
  'created', 'pending', 'pending_verification', 'captured',
  'failed', 'cancelled', 'refund_initiated', 'refunded', 'refund_failed'
);

create type refund_status as enum ('initiated', 'refunded', 'failed');

create type shop_category as enum (
  'bakery', 'restaurant', 'cafe', 'grocery', 'sweets_shop', 'cloud_kitchen', 'other'
);

create type shop_approval_status as enum ('pending_review', 'verified', 'rejected');


-- -----------------------------------------------------------------------------
-- customers — one row per authenticated customer-app user.
-- id is the same UUID as auth.users.id (standard Supabase "profile" pattern).
-- -----------------------------------------------------------------------------
create table customers (
  id uuid primary key references auth.users (id) on delete cascade,
  phone_e164 text not null,
  name text,
  email text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- -----------------------------------------------------------------------------
-- shops — public-facing fields only. Everything a customer is allowed to
-- see (this is what Merchant.dart maps to). Bank details and other private
-- back-office fields live in shop_billing instead, so a public SELECT
-- policy on this table can never leak them.
--
-- FSSAI licence fields are public on purpose — the customer app's own
-- legal-disclosure UI displays them (Consumer Protection Rules 2020).
-- -----------------------------------------------------------------------------
create table shops (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users (id) on delete cascade,

  display_name text not null,
  legal_name text not null,
  category shop_category not null default 'other',
  food_type_tags text[] not null default '{}',
  certifications text[] not null default '{}',
  logo_url text,
  storefront_photos text[] not null default '{}',
  description text not null default '',

  -- Address (matches core/domain/address.dart on both sides)
  address_line1 text not null,
  address_line2 text,
  floor_or_shop_no text,
  landmark text not null,
  locality text not null,
  city text not null,
  state text not null,
  pincode text not null,
  lat double precision not null,
  lng double precision not null,

  phone text not null,
  operating_hours_text text not null default '',
  grievance_contact text not null default '',
  typical_listing_time text,

  fssai_license_number text not null,
  fssai_license_expiry date not null,

  approval_status shop_approval_status not null default 'pending_review',

  -- Denormalized rating aggregate, updated by a trigger once reviews exist
  -- (out of scope for phase 1 — no reviews table yet).
  rating_average double precision not null default 0,
  rating_count integer not null default 0,
  rating_histogram jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index shops_approval_status_idx on shops (approval_status);
create index shops_location_idx on shops (lat, lng);

-- Private, shop-owner-only fields (bank details, owner's personal info,
-- rejection reason). Split from `shops` specifically so RLS never has to
-- get column-level filtering right — the base table just isn't public.
create table shop_billing (
  shop_id uuid primary key references shops (id) on delete cascade,
  owner_name text not null,
  owner_email text not null,
  bank_account_holder_name text not null,
  bank_account_number text not null,
  bank_ifsc_code text not null,
  bank_upi_id text,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- -----------------------------------------------------------------------------
-- store_hours — structured per-day open/close, one row per day per shop
-- (matches shop app's StoreHours/DayHours). Informational only, same as
-- today — nothing enforces that a bag's pickup window falls inside these.
-- -----------------------------------------------------------------------------
create table store_hours (
  shop_id uuid not null references shops (id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6), -- 0 = Monday
  is_open boolean not null default true,
  open_hour smallint not null check (open_hour between 0 and 23),
  close_hour smallint not null check (close_hour between 0 and 23),
  primary key (shop_id, day_of_week)
);


-- -----------------------------------------------------------------------------
-- bags — the one entity both apps read/write and need live-synced.
--
-- Reconciles SurpriseBag (customer detail) + BagSummary (customer list,
-- just a column subset of this same table) + ShopBag (shop's editable
-- view). Fields the shop app doesn't capture today (stated_retail_value,
-- safe_until, allergen_notes, pickup_instructions, category_hint,
-- quantity_total) are real columns here — the shop-side bag-edit screen
-- will need new inputs for them when wired up, they're not invented for
-- no reason.
--
-- discount_percent is a generated column, matching the domain comment
-- "server-supplied, never client-computed" — Postgres computes it, no
-- client ever sends a value.
-- -----------------------------------------------------------------------------
create table bags (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops (id) on delete cascade,

  title text not null,
  description text not null default '',
  dietary_envelope dietary_envelope not null,
  category_hint text not null default '',
  tags text[] not null default '{}', -- shop's fixed vocabulary: Breakfast/Lunch/Dinner/Dessert/Snacks/Beverages

  price_paise bigint not null check (price_paise > 0),
  stated_retail_value_paise bigint not null,
  currency text not null default 'INR',
  discount_percent integer generated always as (
    case when stated_retail_value_paise > 0
      then round(100 - (price_paise::numeric / stated_retail_value_paise * 100))::integer
      else 0
    end
  ) stored,

  quantity_total integer not null check (quantity_total >= 0),
  quantity_available integer not null check (quantity_available >= 0),
  purchase_cap_per_customer integer not null default 2,

  pickup_start_at timestamptz not null,
  pickup_end_at timestamptz not null,
  safe_until timestamptz not null,

  image_url text,
  allergen_notes text,
  pickup_instructions text not null default '',

  status bag_status not null default 'draft',
  repeats_daily boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint bags_price_below_retail check (price_paise < stated_retail_value_paise),
  constraint bags_quantity_available_bounded check (quantity_available <= quantity_total),
  constraint bags_pickup_within_safe_window check (pickup_end_at <= safe_until),
  constraint bags_pickup_window_valid check (pickup_start_at < pickup_end_at)
);

create index bags_shop_id_idx on bags (shop_id);
create index bags_status_idx on bags (status) where status = 'live';
create index bags_pickup_end_idx on bags (pickup_end_at);


-- -----------------------------------------------------------------------------
-- orders — reconciles the customer app's rich Order (snapshots, price
-- breakdown, payment) with the shop app's flat ShopOrder. The shop app
-- gets real bag_id/customer_id FKs it doesn't have today (it currently
-- only stores denormalized bagTitle/customerName strings) — those become
-- real joins once wired up, with customer_snapshot below covering the
-- *display* need without giving the shop RLS access to the customers
-- table (matching the existing "no customer-account detail crosses into
-- the shop's view" rule exactly).
-- -----------------------------------------------------------------------------
create table orders (
  id uuid primary key default gen_random_uuid(),
  order_code text not null unique,

  customer_id uuid not null references customers (id),
  shop_id uuid not null references shops (id), -- denormalized from bag_id, avoids a join in RLS policies
  bag_id uuid not null references bags (id),

  quantity integer not null check (quantity > 0),

  -- Immutable point-in-time copies — a later shop/bag edit must never
  -- change how a past order renders. Minimal on purpose: the shop side
  -- only ever needs a display name, never phone/email (see above).
  shop_snapshot jsonb not null,
  bag_snapshot jsonb not null,
  customer_snapshot jsonb not null, -- { "name": "..." } only

  price_breakdown jsonb not null, -- { bagSubtotal, platformFee, taxes: [...], discount, total } in paise

  pickup_start_at timestamptz not null,
  pickup_end_at timestamptz not null,

  status order_status not null default 'pending_payment',

  pickup_token jsonb, -- { rotatingPayload, rotationExpiresAt, offlineToken, offlineTokenValidUntil, fallbackCode }

  created_at timestamptz not null default now(),
  collected_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  updated_at timestamptz not null default now()
);

create index orders_customer_id_idx on orders (customer_id);
create index orders_shop_id_idx on orders (shop_id);
create index orders_bag_id_idx on orders (bag_id);
create index orders_status_idx on orders (status);

-- Short human-readable codes like "SV-7K2M".
create or replace function generate_order_code() returns text as $$
declare
  chars text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- excludes 0/O, 1/I/L
  code text := 'SV-';
begin
  for i in 1..4 loop
    code := code || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  end loop;
  return code;
end;
$$ language plpgsql;

create or replace function set_order_code() returns trigger as $$
begin
  if new.order_code is null then
    new.order_code := generate_order_code();
  end if;
  return new;
end;
$$ language plpgsql;

create trigger orders_set_code before insert on orders
  for each row execute function set_order_code();


-- -----------------------------------------------------------------------------
-- payments / refunds — modelled for shape now, not wired to a real
-- gateway yet (the apps use PaymentGatewayFake / a hardcoded OTP). Safe
-- to leave mostly unused until real payment integration happens.
-- -----------------------------------------------------------------------------
create table payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references orders (id) on delete cascade,
  method payment_method not null,
  gateway_ref text,
  amount_paise bigint not null,
  status payment_status not null default 'created',
  attempts integer not null default 0,
  masked_identifier text,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references payments (id) on delete cascade,
  amount_paise bigint not null,
  reason text not null,
  status refund_status not null default 'initiated',
  initiated_at timestamptz not null default now(),
  expected_by_at timestamptz not null
);


-- -----------------------------------------------------------------------------
-- payouts — shop-side earnings payout requests (matches PayoutRecord).
-- -----------------------------------------------------------------------------
create table payouts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops (id) on delete cascade,
  requested_at timestamptz not null default now(),
  amount_paise bigint not null
);

create table payout_order_items (
  payout_id uuid not null references payouts (id) on delete cascade,
  order_id uuid not null references orders (id),
  primary key (payout_id, order_id)
);


-- -----------------------------------------------------------------------------
-- shop_notifications — matches ShopNotification.
-- -----------------------------------------------------------------------------
create table shop_notifications (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops (id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now(),
  read boolean not null default false
);

create index shop_notifications_shop_id_idx on shop_notifications (shop_id) where read = false;


-- =============================================================================
-- Row Level Security
-- =============================================================================

alter table customers enable row level security;
alter table shops enable row level security;
alter table shop_billing enable row level security;
alter table store_hours enable row level security;
alter table bags enable row level security;
alter table orders enable row level security;
alter table payments enable row level security;
alter table refunds enable row level security;
alter table payouts enable row level security;
alter table payout_order_items enable row level security;
alter table shop_notifications enable row level security;

-- customers: a user can only read/write their own row.
create policy customers_self on customers
  for all using (id = auth.uid()) with check (id = auth.uid());

-- shops: public read for verified shops (customer app catalog); owner
-- gets full read/write on their own shop regardless of approval status
-- (so they can see their own pending/rejected registration).
create policy shops_public_read on shops
  for select using (approval_status = 'verified' or auth_user_id = auth.uid());
create policy shops_owner_write on shops
  for insert with check (auth_user_id = auth.uid());
create policy shops_owner_update on shops
  for update using (auth_user_id = auth.uid());

-- shop_billing: owner only, never public.
create policy shop_billing_owner_only on shop_billing
  for all using (
    shop_id in (select id from shops where auth_user_id = auth.uid())
  ) with check (
    shop_id in (select id from shops where auth_user_id = auth.uid())
  );

-- store_hours: public read (customers may want to see hours), owner write.
create policy store_hours_public_read on store_hours for select using (true);
create policy store_hours_owner_write on store_hours
  for insert with check (shop_id in (select id from shops where auth_user_id = auth.uid()));
create policy store_hours_owner_update on store_hours
  for update using (shop_id in (select id from shops where auth_user_id = auth.uid()));
create policy store_hours_owner_delete on store_hours
  for delete using (shop_id in (select id from shops where auth_user_id = auth.uid()));

-- bags: public read for any bag that has ever been published (everything
-- except 'draft'), from verified shops; shop owner gets full read/write on
-- their own bags regardless of status (drafts included). Gating on
-- `status = 'live'` alone (the original version of this policy) hid a bag
-- from everyone but its owner the instant it sold out / had its window
-- close / got withdrawn — which broke the app's own sold-out/withdrawn
-- messaging (bag detail, checkout) into a generic "not found", since the
-- row became genuinely unreadable rather than readable-but-unavailable.
-- Bags aren't sensitive data (no pricing secrets, no PII) — the only thing
-- actually worth hiding pre-publish is a shop's still-being-drafted listing.
create policy bags_public_read on bags
  for select using (
    status <> 'draft'
    or shop_id in (select id from shops where auth_user_id = auth.uid())
  );
create policy bags_owner_write on bags
  for insert with check (shop_id in (select id from shops where auth_user_id = auth.uid()));
create policy bags_owner_update on bags
  for update using (shop_id in (select id from shops where auth_user_id = auth.uid()));
create policy bags_owner_delete on bags
  for delete using (shop_id in (select id from shops where auth_user_id = auth.uid()));

-- orders: customer sees/creates their own; shop sees/updates orders
-- against their own bags (to confirm pickup, mark no-show, etc.) but
-- never creates one directly.
create policy orders_customer_read on orders
  for select using (customer_id = auth.uid());
create policy orders_customer_create on orders
  for insert with check (customer_id = auth.uid());
create policy orders_shop_read on orders
  for select using (shop_id in (select id from shops where auth_user_id = auth.uid()));
create policy orders_shop_update on orders
  for update using (shop_id in (select id from shops where auth_user_id = auth.uid()));

-- payments/refunds: customer-only (matches "no payment detail crosses
-- into the shop's view"). Shops get no policy at all on these tables.
create policy payments_customer_read on payments
  for select using (
    order_id in (select id from orders where customer_id = auth.uid())
  );
create policy refunds_customer_read on refunds
  for select using (
    payment_id in (
      select p.id from payments p
      join orders o on o.id = p.order_id
      where o.customer_id = auth.uid()
    )
  );

-- Placing an order needs to insert an `orders` row (covered by
-- orders_customer_create), decrement `bags.quantity_available` (the bag
-- belongs to the *shop*, not the customer — no RLS policy should ever let a
-- customer write to it directly), and insert a `payments` row (no
-- customer-facing insert policy exists on `payments` at all, by design —
-- see the payments/refunds comment above). A `security definer` function is
-- the correct way to let a customer trigger exactly this one bounded write
-- across two tables they don't otherwise own, instead of loosening RLS on
-- `bags`/`payments` broadly. It re-validates live stock itself (never trust
-- the client) and locks the bag row (`for update`) so two simultaneous
-- purchases can't both succeed against the last unit.
create or replace function create_order_and_pay(
  p_bag_id uuid,
  p_quantity integer,
  p_shop_snapshot jsonb,
  p_bag_snapshot jsonb,
  p_customer_snapshot jsonb,
  p_price_breakdown jsonb,
  p_pickup_start_at timestamptz,
  p_pickup_end_at timestamptz,
  p_pickup_token jsonb,
  p_payment_method payment_method,
  p_gateway_ref text,
  p_amount_paise bigint
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_shop_id uuid;
  v_available integer;
  v_status bag_status;
  v_order orders%rowtype;
  v_payment payments%rowtype;
begin
  if v_customer_id is null then
    raise exception 'not authenticated';
  end if;

  select shop_id, quantity_available, status
    into v_shop_id, v_available, v_status
    from bags where id = p_bag_id
    for update;

  if not found then
    raise exception 'bag not found';
  end if;
  if v_status <> 'live' then
    raise exception 'bag is not live';
  end if;
  if v_available < p_quantity then
    raise exception 'insufficient stock';
  end if;

  insert into orders (
    customer_id, shop_id, bag_id, quantity, shop_snapshot, bag_snapshot,
    customer_snapshot, price_breakdown, pickup_start_at, pickup_end_at,
    status, pickup_token
  ) values (
    v_customer_id, v_shop_id, p_bag_id, p_quantity, p_shop_snapshot, p_bag_snapshot,
    p_customer_snapshot, p_price_breakdown, p_pickup_start_at, p_pickup_end_at,
    'confirmed', p_pickup_token
  ) returning * into v_order;

  update bags
    set quantity_available = v_available - p_quantity,
        status = case when v_available - p_quantity <= 0 then 'sold_out' else status end,
        updated_at = now()
    where id = p_bag_id;

  insert into payments (
    order_id, method, gateway_ref, amount_paise, status, attempts
  ) values (
    v_order.id, p_payment_method, p_gateway_ref, p_amount_paise, 'captured', 1
  ) returning * into v_payment;

  return jsonb_build_object('order', to_jsonb(v_order), 'payment', to_jsonb(v_payment));
end;
$$;

grant execute on function create_order_and_pay to authenticated;

-- Customer-initiated cancellation needs exactly the same shape of fix as
-- create_order_and_pay above: updating the order itself has no RLS problem
-- (orders_customer_create covers insert, but there is deliberately no
-- customer-facing UPDATE policy on orders at all — a customer can create
-- an order, never edit an arbitrary one directly), and giving the
-- reserved stock back writes to `bags`, which the customer doesn't own
-- either way. Re-validates the cancellation window itself (a client-side
-- check alone can't be trusted, and could otherwise race past the cutoff
-- between the UI's own check and the write).
create or replace function cancel_order(
  p_order_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_order orders%rowtype;
  v_cutoff timestamptz;
  v_available integer;
  v_total integer;
  v_status bag_status;
begin
  if v_customer_id is null then
    raise exception 'not authenticated';
  end if;

  select * into v_order from orders
    where id = p_order_id and customer_id = v_customer_id;
  if not found then
    raise exception 'order not found';
  end if;

  v_cutoff := v_order.pickup_start_at - interval '60 minutes';
  if now() >= v_cutoff or v_order.status not in ('pending_payment', 'confirmed') then
    raise exception 'cancellation window passed';
  end if;

  update orders
    set status = 'cancelled_by_customer',
        cancelled_at = now(),
        cancellation_reason = p_reason,
        updated_at = now()
    where id = p_order_id
    returning * into v_order;

  select quantity_available, quantity_total, status
    into v_available, v_total, v_status
    from bags where id = v_order.bag_id
    for update;

  if found then
    update bags
      set quantity_available = least(v_available + v_order.quantity, v_total),
          status = case when v_status = 'sold_out' then 'live' else status end,
          updated_at = now()
      where id = v_order.bag_id;
  end if;

  return to_jsonb(v_order);
end;
$$;

grant execute on function cancel_order to authenticated;

-- payouts / payout_order_items / shop_notifications: owner only.
create policy payouts_owner_only on payouts
  for all using (shop_id in (select id from shops where auth_user_id = auth.uid()))
  with check (shop_id in (select id from shops where auth_user_id = auth.uid()));
create policy payout_order_items_owner_only on payout_order_items
  for all using (
    payout_id in (
      select id from payouts where shop_id in (select id from shops where auth_user_id = auth.uid())
    )
  );
create policy shop_notifications_owner_only on shop_notifications
  for all using (shop_id in (select id from shops where auth_user_id = auth.uid()))
  with check (shop_id in (select id from shops where auth_user_id = auth.uid()));


-- =============================================================================
-- admins — the back office. One row per admin's Supabase Auth user id,
-- same account-creation pattern as a shop's optional email+password login
-- (create the user via the Supabase dashboard's Authentication > Users >
-- "Add user", then insert their id here — never a public sign-up path).
-- =============================================================================
create table admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table admins enable row level security;

-- An admin can confirm their own membership (the shop app's login flow
-- checks this to decide whether to route into the back office).
create policy admins_self_read on admins
  for select using (user_id = auth.uid());

-- Read access the back office needs: every shop, every order, regardless
-- of which owner/customer they belong to.
create policy shops_admin_read on shops
  for select using (exists (select 1 from admins where user_id = auth.uid()));
create policy orders_admin_read on orders
  for select using (exists (select 1 from admins where user_id = auth.uid()));

-- Write access: approve/reject/deactivate/reactivate a shop (and its
-- rejection reason), and cancel any order (with its stock restored).
create policy shops_admin_update on shops
  for update using (exists (select 1 from admins where user_id = auth.uid()));
create policy shop_billing_admin_update on shop_billing
  for update using (exists (select 1 from admins where user_id = auth.uid()));
create policy orders_admin_update on orders
  for update using (exists (select 1 from admins where user_id = auth.uid()));
create policy bags_admin_update on bags
  for update using (exists (select 1 from admins where user_id = auth.uid()));

-- Blocks a shop from approving itself through its own existing update
-- policy (`shops_owner_update` lets a shop edit its address/phone/etc.,
-- but was never meant to let it flip its own approval_status) — silently
-- reverts approval_status to whatever it already was unless the caller is
-- an admin, rather than rejecting the whole update (a shop editing its
-- address shouldn't get an error just because approval_status came along
-- unchanged in the same row).
create or replace function prevent_self_approval() returns trigger as $$
begin
  if new.approval_status <> old.approval_status
     and not exists (select 1 from admins where user_id = auth.uid()) then
    new.approval_status := old.approval_status;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

create trigger shops_prevent_self_approval
  before update on shops
  for each row execute function prevent_self_approval();


-- =============================================================================
-- Realtime — the actual point of this whole schema. Both apps subscribe
-- to these two tables so a change on one side shows up live on the other
-- with no manual refresh.
-- =============================================================================
alter publication supabase_realtime add table bags;
alter publication supabase_realtime add table orders;

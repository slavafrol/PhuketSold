-- Inventory foundation only. Auth credentials, Storage provisioning, offers and chat
-- remain separate concerns. Application tables are accessed through the .NET API.
begin;

create schema marketplace;
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;

-- A privilege group, not a login. Provision a dedicated API login separately;
-- never grant this role to anon, authenticated, authenticator or browser users.
create role phuketsold_api nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
revoke all on schema marketplace from public, anon, authenticated;
grant usage on schema marketplace to phuketsold_api;
grant usage on schema extensions to phuketsold_api;
alter default privileges in schema marketplace revoke execute on functions from public;

create table marketplace.profiles (
    id uuid primary key references auth.users(id) on delete restrict,
    display_name text not null check (char_length(btrim(display_name)) between 1 and 80),
    preferred_language text not null default 'en' check (preferred_language in ('en', 'th', 'ru')),
    archived_at timestamptz,
    created_at timestamptz not null default statement_timestamp(),
    updated_at timestamptz not null default statement_timestamp(),
    version bigint not null default 1 check (version > 0)
);
comment on table marketplace.profiles is
    'Display identity only. Phone numbers and provider identities remain in Auth; private contact consent is a later slice.';

create table marketplace.categories (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 80),
    name_en text not null check (char_length(btrim(name_en)) between 1 and 120),
    name_th text not null check (char_length(btrim(name_th)) between 1 and 120),
    name_ru text not null check (char_length(btrim(name_ru)) between 1 and 120),
    is_active boolean not null default true,
    sort_order integer not null default 0 check (sort_order >= 0),
    created_at timestamptz not null default statement_timestamp(),
    updated_at timestamptz not null default statement_timestamp(),
    version bigint not null default 1 check (version > 0)
);

create table marketplace.areas (
    id uuid primary key default gen_random_uuid(),
    slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 80),
    name_en text not null check (char_length(btrim(name_en)) between 1 and 120),
    name_th text not null check (char_length(btrim(name_th)) between 1 and 120),
    name_ru text not null check (char_length(btrim(name_ru)) between 1 and 120),
    is_active boolean not null default true,
    sort_order integer not null default 0 check (sort_order >= 0),
    created_at timestamptz not null default statement_timestamp(),
    updated_at timestamptz not null default statement_timestamp(),
    version bigint not null default 1 check (version > 0)
);

create table marketplace.developments (
    id uuid primary key default gen_random_uuid(),
    area_id uuid not null references marketplace.areas(id) on delete restrict,
    slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 100),
    name_en text not null check (char_length(btrim(name_en)) between 1 and 160),
    name_th text not null check (char_length(btrim(name_th)) between 1 and 160),
    name_ru text not null check (char_length(btrim(name_ru)) between 1 and 160),
    kind text not null check (kind in ('village', 'condominium', 'development')),
    is_active boolean not null default true,
    created_at timestamptz not null default statement_timestamp(),
    updated_at timestamptz not null default statement_timestamp(),
    version bigint not null default 1 check (version > 0),
    unique (id, area_id)
);
create index developments_area_idx on marketplace.developments(area_id);

create table marketplace.listing_groups (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references marketplace.profiles(id) on delete restrict,
    listing_type text not null check (listing_type in ('sell', 'buy')),
    slug text unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 120),
    title text not null check (char_length(btrim(title)) between 1 and 160),
    description text not null default '' check (char_length(description) <= 10000),
    source_language text not null default 'en' check (source_language in ('en', 'th', 'ru')),
    area_id uuid references marketplace.areas(id) on delete restrict,
    development_id uuid,
    available_until timestamptz,
    archived_at timestamptz,
    created_at timestamptz not null default statement_timestamp(),
    updated_at timestamptz not null default statement_timestamp(),
    version bigint not null default 1 check (version > 0),
    unique (id, owner_id, listing_type),
    foreign key (development_id, area_id) references marketplace.developments(id, area_id) on delete restrict,
    check (development_id is null or area_id is not null)
);
create index listing_groups_owner_idx on marketplace.listing_groups(owner_id, created_at desc, id desc);
create index listing_groups_area_idx on marketplace.listing_groups(area_id);
create index listing_groups_development_idx on marketplace.listing_groups(development_id, area_id);

create table marketplace.listings (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references marketplace.profiles(id) on delete restrict,
    listing_type text not null check (listing_type in ('sell', 'buy')),
    group_id uuid,
    slug text unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 160),
    title text check (char_length(btrim(title)) between 1 and 160),
    description text not null default '' check (char_length(description) <= 10000),
    source_language text not null default 'en' check (source_language in ('en', 'th', 'ru')),
    category_id uuid references marketplace.categories(id) on delete restrict,
    price_thb bigint check (price_thb between 0 and 1000000000),
    item_condition text check (char_length(btrim(item_condition)) between 1 and 80),
    area_id uuid references marketplace.areas(id) on delete restrict,
    development_id uuid,
    status text not null default 'draft' check (status in ('draft', 'active', 'reserved', 'sold', 'expired', 'archived')),
    published_at timestamptz,
    expires_at timestamptz,
    archived_at timestamptz,
    hidden_at timestamptz,
    created_at timestamptz not null default statement_timestamp(),
    updated_at timestamptz not null default statement_timestamp(),
    version bigint not null default 1 check (version > 0),
    foreign key (group_id, owner_id, listing_type)
        references marketplace.listing_groups(id, owner_id, listing_type) on delete restrict,
    foreign key (development_id, area_id) references marketplace.developments(id, area_id) on delete restrict,
    check (development_id is null or area_id is not null),
    check (status in ('draft', 'archived') or
        (title is not null and category_id is not null and price_thb is not null and area_id is not null
         and published_at is not null and expires_at is not null)),
    check ((status = 'archived') = (archived_at is not null)),
    check (expires_at is null or (published_at is not null and expires_at > published_at))
);
comment on column marketplace.listings.price_thb is 'Whole THB; target price for buy listings. Zero permits free items.';
comment on column marketplace.listings.version is 'Optimistic concurrency: UPDATE ... WHERE id = @id AND owner_id = @user AND version = @expected.';

create index listings_owner_idx on marketplace.listings(owner_id, status, updated_at desc, id desc);
create index listings_group_idx on marketplace.listings(group_id, owner_id, listing_type);
create index listings_category_idx on marketplace.listings(category_id);
create index listings_area_idx on marketplace.listings(area_id);
create index listings_development_idx on marketplace.listings(development_id, area_id);
create index listings_active_newest_idx on marketplace.listings(listing_type, published_at desc, id desc)
    where status = 'active' and hidden_at is null;
create index listings_active_price_idx on marketplace.listings(listing_type, price_thb, id)
    where status = 'active' and hidden_at is null;
create index listings_expiry_idx on marketplace.listings(expires_at, id)
    where status in ('active', 'reserved');
-- Trigrams support substring search in all three languages, including unsegmented
-- Thai. The API must escape LIKE wildcards and bound short (<3 character) searches.
create index listings_active_text_idx on marketplace.listings using gin
    (lower(coalesce(title, '') || ' ' || description) extensions.gin_trgm_ops)
    where status = 'active' and hidden_at is null;

create table marketplace.listing_images (
    id uuid primary key default gen_random_uuid(),
    listing_id uuid not null references marketplace.listings(id) on delete restrict,
    position smallint not null check (position between 0 and 11),
    is_cover boolean not null default false,
    storage_bucket text not null check (char_length(btrim(storage_bucket)) between 1 and 100),
    storage_path text not null check (char_length(storage_path) between 1 and 1024 and storage_path !~ '(^/|(^|/)\.\.(/|$))'),
    thumbnail_path text check (char_length(thumbnail_path) between 1 and 1024 and thumbnail_path !~ '(^/|(^|/)\.\.(/|$))'),
    card_path text check (char_length(card_path) between 1 and 1024 and card_path !~ '(^/|(^|/)\.\.(/|$))'),
    display_path text check (char_length(display_path) between 1 and 1024 and display_path !~ '(^/|(^|/)\.\.(/|$))'),
    content_type text not null check (content_type in ('image/jpeg', 'image/png', 'image/webp', 'image/avif')),
    width integer not null check (width between 1 and 16384),
    height integer not null check (height between 1 and 16384),
    byte_size bigint not null check (byte_size > 0),
    processing_status text not null default 'pending' check (processing_status in ('pending', 'ready', 'failed')),
    created_at timestamptz not null default statement_timestamp(),
    updated_at timestamptz not null default statement_timestamp(),
    version bigint not null default 1 check (version > 0),
    unique (storage_bucket, storage_path),
    constraint listing_images_position_unique unique (listing_id, position) deferrable initially immediate,
    check (processing_status <> 'ready' or
        (thumbnail_path is not null and card_path is not null and display_path is not null))
);
create unique index listing_images_cover_idx on marketplace.listing_images(listing_id) where is_cover;
comment on table marketplace.listing_images is
    'At most 12 unique slots. Paths are immutable object references, not signed URLs. Metadata is finalized by a trusted media pipeline.';

create table marketplace.listing_events (
    id uuid primary key default gen_random_uuid(),
    listing_id uuid not null references marketplace.listings(id) on delete restrict,
    actor_id uuid references marketplace.profiles(id) on delete restrict,
    event_type text not null check (event_type in ('created', 'updated', 'status_changed')),
    old_status text check (old_status in ('draft', 'active', 'reserved', 'sold', 'expired', 'archived')),
    new_status text not null check (new_status in ('draft', 'active', 'reserved', 'sold', 'expired', 'archived')),
    listing_version bigint not null check (listing_version > 0),
    changed_fields text[] not null default '{}',
    created_at timestamptz not null default statement_timestamp(),
    unique (listing_id, listing_version)
);
create index listing_events_history_idx on marketplace.listing_events(listing_id, created_at desc, id desc);
create index listing_events_actor_idx on marketplace.listing_events(actor_id) where actor_id is not null;
comment on table marketplace.listing_events is
    'Append-only state/version history; field names only, never old descriptions, contact data or message bodies. A null actor denotes trusted maintenance.';

create function marketplace.control_row_metadata() returns trigger
language plpgsql set search_path = '' as $$
begin
    if tg_op = 'INSERT' then
        new.created_at := statement_timestamp();
        new.version := 1;
    else
        if new.id is distinct from old.id or new.created_at is distinct from old.created_at then
            raise exception 'Identity and creation time are immutable' using errcode = '23514';
        end if;
        new.version := old.version + 1;
    end if;
    new.updated_at := statement_timestamp();
    return new;
end;
$$;

create function marketplace.control_listing_identity() returns trigger
language plpgsql set search_path = '' as $$
begin
    if new.owner_id is distinct from old.owner_id or new.listing_type is distinct from old.listing_type
       or (old.slug is not null and new.slug is distinct from old.slug) then
        raise exception 'Owner, listing type and assigned slug are immutable' using errcode = '23514';
    end if;
    return new;
end;
$$;

create function marketplace.control_listing_lifecycle() returns trigger
language plpgsql set search_path = '' as $$
begin
    if tg_op = 'INSERT' then
        if new.status not in ('draft', 'active') then
            raise exception 'A new listing must be draft or active' using errcode = '23514';
        end if;
        new.published_at := null;
    elsif old.published_at is not null and new.published_at is distinct from old.published_at then
        raise exception 'First publication time is immutable' using errcode = '23514';
    elsif old.published_at is null then
        new.published_at := null;
    end if;

    if new.status = 'active' and new.published_at is null then
        new.published_at := statement_timestamp();
        new.expires_at := coalesce(new.expires_at, new.published_at + interval '30 days');
    end if;
    if new.status = 'active' and new.expires_at <= statement_timestamp() then
        raise exception 'An active listing must have a future expiry' using errcode = '23514';
    end if;
    if new.status = 'archived' then
        new.archived_at := coalesce(new.archived_at, statement_timestamp());
    else
        new.archived_at := null;
    end if;
    return new;
end;
$$;

create function marketplace.control_image_identity() returns trigger
language plpgsql set search_path = '' as $$
begin
    if new.listing_id is distinct from old.listing_id
       or new.storage_bucket is distinct from old.storage_bucket
       or new.storage_path is distinct from old.storage_path then
        raise exception 'Image ownership and object path are immutable; replace with a new image' using errcode = '23514';
    end if;
    return new;
end;
$$;

-- Only this trigger may append events. The API uses a transaction-local actor ID
-- after JWT validation; maintenance connections may omit it. No client can call it.
create function marketplace.record_listing_event() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
    previous_status text;
    changed text[] := '{}';
begin
    if tg_op = 'UPDATE' then
        previous_status := old.status;
        select coalesce(array_agg(n.key order by n.key), '{}') into changed
        from jsonb_each(to_jsonb(new)) n
        where n.key not in ('updated_at', 'version')
          and n.value is distinct from (to_jsonb(old) -> n.key);
    end if;
    insert into marketplace.listing_events
        (listing_id, actor_id, event_type, old_status, new_status, listing_version, changed_fields)
    values (new.id, nullif(current_setting('app.actor_id', true), '')::uuid,
        case when tg_op = 'INSERT' then 'created'
             when old.status is distinct from new.status then 'status_changed' else 'updated' end,
        previous_status, new.status, new.version, changed);
    return new;
end;
$$;

do $$
declare
    table_name text;
begin
    foreach table_name in array array['profiles', 'categories', 'areas', 'developments', 'listing_groups', 'listings', 'listing_images'] loop
        execute format('create trigger a_control_metadata before insert or update on marketplace.%I for each row execute function marketplace.control_row_metadata()', table_name);
    end loop;
    foreach table_name in array array['listing_groups', 'listings'] loop
        execute format('create trigger b_control_identity before update on marketplace.%I for each row execute function marketplace.control_listing_identity()', table_name);
    end loop;
    foreach table_name in array array['profiles', 'categories', 'areas', 'developments', 'listing_groups', 'listings', 'listing_images', 'listing_events'] loop
        execute format('alter table marketplace.%I enable row level security', table_name);
        execute format('revoke all on marketplace.%I from public, anon, authenticated', table_name);
        execute format('create policy api_access on marketplace.%I to phuketsold_api using (true) with check (true)', table_name);
    end loop;
end;
$$;

create trigger c_control_lifecycle before insert or update on marketplace.listings
    for each row execute function marketplace.control_listing_lifecycle();
create trigger z_record_event after insert or update on marketplace.listings
    for each row execute function marketplace.record_listing_event();
create trigger b_control_image_identity before update on marketplace.listing_images
    for each row execute function marketplace.control_image_identity();

grant select on all tables in schema marketplace to phuketsold_api;
grant insert, update on marketplace.profiles, marketplace.listing_groups, marketplace.listings, marketplace.listing_images to phuketsold_api;
grant delete on marketplace.listing_images to phuketsold_api;
revoke all on all functions in schema marketplace from public, anon, authenticated;

commit;

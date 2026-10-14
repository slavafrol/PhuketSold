-- Run with ON_ERROR_STOP on a disposable local database after migrations and seed.
-- All fixtures and temporary grants roll back. No Auth provider is exercised.
begin;

-- Supabase's postgres role is a restricted administrator, not a superuser. It
-- creates the API privilege group but needs an explicit test-only SET grant.
grant phuketsold_api to current_user with inherit false, set true;

do $$
declare
    browser_role text;
    application_table record;
begin
    foreach browser_role in array array['anon', 'authenticated'] loop
        if has_schema_privilege(browser_role, 'marketplace', 'USAGE') then
            raise exception 'Browser role % has schema access', browser_role;
        end if;
        for application_table in select oid, relname, relrowsecurity from pg_class
            where relnamespace = 'marketplace'::regnamespace and relkind = 'r' loop
            if not application_table.relrowsecurity then
                raise exception 'RLS disabled on %', application_table.relname;
            end if;
            if has_table_privilege(browser_role, application_table.oid, 'SELECT,INSERT,UPDATE,DELETE') then
                raise exception 'Browser role % has table privileges on %', browser_role, application_table.relname;
            end if;
        end loop;
    end loop;
    if has_table_privilege('phuketsold_api', 'marketplace.listing_events', 'INSERT,UPDATE,DELETE')
       or has_table_privilege('phuketsold_api', 'marketplace.listings', 'DELETE')
       or has_table_privilege('phuketsold_api', 'marketplace.categories', 'INSERT,UPDATE,DELETE') then
        raise exception 'API can erase history or modify curated reference data';
    end if;
    if exists (select 1 from pg_roles where rolname = 'phuketsold_api' and (rolcanlogin or rolbypassrls or rolsuper)) then
        raise exception 'API privilege group has unsafe role attributes';
    end if;
end;
$$;

insert into auth.users (id) values
    ('40000000-0000-4000-8000-000000000001'),
    ('40000000-0000-4000-8000-000000000002');

set local role phuketsold_api;
insert into marketplace.profiles (id, display_name) values
    ('40000000-0000-4000-8000-000000000001', 'Demo Seller'),
    ('40000000-0000-4000-8000-000000000002', 'Demo Requester');
select set_config('app.actor_id', '40000000-0000-4000-8000-000000000001', true);

insert into marketplace.listing_groups (id, owner_id, listing_type, title) values
    ('50000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'sell', 'Demo Sale'),
    ('50000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', 'buy', 'Demo Wanted List');

insert into marketplace.listings (id, owner_id, listing_type, group_id) values
    ('60000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', 'sell', '50000000-0000-4000-8000-000000000001');

do $$
declare
    affected integer;
    initial_created_at timestamptz;
begin
    -- Incomplete drafts are allowed; publication requires the inventory fields.
    begin
        update marketplace.listings set status = 'active' where id = '60000000-0000-4000-8000-000000000001';
        raise exception 'Incomplete listing published';
    exception when check_violation then null;
    end;
    begin
        insert into marketplace.listings (owner_id, listing_type, group_id)
        values ('40000000-0000-4000-8000-000000000002', 'sell', '50000000-0000-4000-8000-000000000001');
        raise exception 'Another owner joined a group';
    exception when foreign_key_violation then null;
    end;
    begin
        insert into marketplace.listings (owner_id, listing_type, group_id)
        values ('40000000-0000-4000-8000-000000000002', 'sell', '50000000-0000-4000-8000-000000000002');
        raise exception 'Sell listing joined a wanted list';
    exception when foreign_key_violation then null;
    end;
    begin
        update marketplace.listings set area_id = '20000000-0000-4000-8000-000000000002',
            development_id = '30000000-0000-4000-8000-000000000001'
        where id = '60000000-0000-4000-8000-000000000001';
        raise exception 'Development linked to incorrect area';
    exception when foreign_key_violation then null;
    end;
    begin
        update marketplace.listings set price_thb = -1 where id = '60000000-0000-4000-8000-000000000001';
        raise exception 'Negative price accepted';
    exception when check_violation then null;
    end;

    select created_at into initial_created_at from marketplace.listings where id = '60000000-0000-4000-8000-000000000001';
    update marketplace.listings set status = 'active', title = 'Demo โต๊ะ Стол', price_thb = 500,
        category_id = '10000000-0000-4000-8000-000000000001',
        area_id = '20000000-0000-4000-8000-000000000001',
        development_id = '30000000-0000-4000-8000-000000000001', slug = 'demo-table'
    where id = '60000000-0000-4000-8000-000000000001' and version = 1;
    get diagnostics affected = row_count;
    if affected <> 1 or not exists (select 1 from marketplace.listings
        where id = '60000000-0000-4000-8000-000000000001' and version = 2
          and created_at = initial_created_at and expires_at = published_at + interval '30 days') then
        raise exception 'Publication, version or 30-day expiry failed';
    end if;

    update marketplace.listings set price_thb = 600 where id = '60000000-0000-4000-8000-000000000001' and version = 1;
    get diagnostics affected = row_count;
    if affected <> 0 then raise exception 'Stale version overwrote listing'; end if;

    begin
        update marketplace.listings set owner_id = '40000000-0000-4000-8000-000000000002'
        where id = '60000000-0000-4000-8000-000000000001';
        raise exception 'Owner changed';
    exception when check_violation then null;
    end;
    begin
        update marketplace.listings set slug = 'different-url' where id = '60000000-0000-4000-8000-000000000001';
        raise exception 'Assigned URL slug changed';
    exception when check_violation then null;
    end;
    begin
        update marketplace.listings set published_at = published_at - interval '1 day'
        where id = '60000000-0000-4000-8000-000000000001';
        raise exception 'Publication time changed';
    exception when check_violation then null;
    end;
    begin
        update marketplace.listings set expires_at = published_at - interval '1 day'
        where id = '60000000-0000-4000-8000-000000000001';
        raise exception 'Past active expiry accepted';
    exception when check_violation then null;
    end;

    if (select count(*) from marketplace.listing_events where listing_id = '60000000-0000-4000-8000-000000000001') <> 2
       or not exists (select 1 from marketplace.listing_events
            where listing_id = '60000000-0000-4000-8000-000000000001' and listing_version = 2
              and event_type = 'status_changed' and old_status = 'draft' and new_status = 'active'
              and actor_id = '40000000-0000-4000-8000-000000000001') then
        raise exception 'Lifecycle history was lost or failed writes created events';
    end if;
end;
$$;

-- Buy/WTB target price and group are independently supported.
insert into marketplace.listings (id, owner_id, listing_type, group_id, status, title, price_thb, category_id, area_id) values
    ('60000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', 'buy',
     '50000000-0000-4000-8000-000000000002', 'active', 'Wanted demo chair', 0,
     '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001');

insert into marketplace.listing_images (listing_id, position, is_cover, storage_bucket, storage_path, content_type, width, height, byte_size)
select '60000000-0000-4000-8000-000000000001', slot, slot = 0, 'demo-media', 'demo/' || slot || '.webp', 'image/webp', 640, 480, 30000
from generate_series(0, 11) slot;

do $$
begin
    begin
        insert into marketplace.listing_images (listing_id, position, storage_bucket, storage_path, content_type, width, height, byte_size)
        values ('60000000-0000-4000-8000-000000000001', 12, 'demo-media', 'demo/12.webp', 'image/webp', 640, 480, 30000);
        raise exception 'Thirteenth image accepted';
    exception when check_violation then null;
    end;
    begin
        update marketplace.listing_images set is_cover = true
        where listing_id = '60000000-0000-4000-8000-000000000001' and position = 1;
        raise exception 'Multiple covers accepted';
    exception when unique_violation then null;
    end;
    begin
        update marketplace.listing_images set processing_status = 'ready'
        where listing_id = '60000000-0000-4000-8000-000000000001' and position = 0;
        raise exception 'Ready image lacks optimized variants';
    exception when check_violation then null;
    end;
    begin
        update marketplace.listing_images set listing_id = '60000000-0000-4000-8000-000000000002'
        where listing_id = '60000000-0000-4000-8000-000000000001' and position = 0;
        raise exception 'Image transferred to another listing';
    exception when check_violation then null;
    end;
end;
$$;

set constraints marketplace.listing_images_position_unique deferred;
update marketplace.listing_images set position = case position when 0 then 1 when 1 then 0 end
where listing_id = '60000000-0000-4000-8000-000000000001' and position in (0, 1);
set constraints marketplace.listing_images_position_unique immediate;

-- SQL-level visibility predicate used by browse endpoints, even if the expiry
-- worker has not yet changed a row's stored status.
update marketplace.listings set status = 'sold' where id = '60000000-0000-4000-8000-000000000001';
do $$
begin
    if exists (select 1 from marketplace.listings where id = '60000000-0000-4000-8000-000000000001' and listing_type = 'sell'
        and status = 'active' and hidden_at is null and expires_at > statement_timestamp()) then
        raise exception 'Sold listing remains in active browse';
    end if;
    if not exists (select 1 from marketplace.listings where slug = 'demo-table' and status = 'sold') then
        raise exception 'Historical direct URL lost';
    end if;
end;
$$;
reset role;

-- Temporarily grant browser SQL privileges to test the RLS barrier independently
-- of the production schema/table grant barrier. These grants are rolled back.
grant usage on schema marketplace to anon, authenticated;
grant select, insert, update, delete on all tables in schema marketplace to anon, authenticated;
set local role anon;
do $$
declare
    table_name text;
    visible_rows bigint;
begin
    foreach table_name in array array['profiles', 'categories', 'areas', 'developments', 'listing_groups', 'listings', 'listing_images', 'listing_events'] loop
        execute format('select count(*) from marketplace.%I', table_name) into visible_rows;
        if visible_rows <> 0 then raise exception 'Anonymous RLS leak on %', table_name; end if;
    end loop;
    begin
        insert into marketplace.profiles (id, display_name) values ('40000000-0000-4000-8000-000000000001', 'Unauthorized');
        raise exception 'Anonymous insert succeeded';
    exception when insufficient_privilege then null;
    end;
end;
$$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"40000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
    table_name text;
    visible_rows bigint;
    affected integer;
begin
    foreach table_name in array array['profiles', 'categories', 'areas', 'developments', 'listing_groups', 'listings', 'listing_images', 'listing_events'] loop
        execute format('select count(*) from marketplace.%I', table_name) into visible_rows;
        if visible_rows <> 0 then raise exception 'Authenticated RLS leak on %', table_name; end if;
        execute format('update marketplace.%I set id = id', table_name);
        get diagnostics affected = row_count;
        if affected <> 0 then raise exception 'Authenticated update reached %', table_name; end if;
        execute format('delete from marketplace.%I', table_name);
        get diagnostics affected = row_count;
        if affected <> 0 then raise exception 'Authenticated delete reached %', table_name; end if;
    end loop;
    begin
        insert into marketplace.listings (owner_id, listing_type) values ('40000000-0000-4000-8000-000000000001', 'sell');
        raise exception 'Authenticated insert succeeded';
    exception when insufficient_privilege then null;
    end;
end;
$$;
reset role;
rollback;

-- Disposable local database only; requires migrations and seed. Fixtures and
-- ANALYZE statistics roll back. Inspect plans, not absolute timings on toy data.
begin;
grant phuketsold_api to current_user with inherit false, set true;
insert into auth.users (id) values ('70000000-0000-4000-8000-000000000001');
insert into marketplace.profiles (id, display_name) values ('70000000-0000-4000-8000-000000000001', 'Plan Fixture');
insert into marketplace.listings (owner_id, listing_type, status, title, description, price_thb, category_id, area_id)
select '70000000-0000-4000-8000-000000000001',
    case when n % 4 = 0 then 'buy' else 'sell' end,
    'active',
    case when n % 100 = 0 then 'Rarecamera กล้อง Фотоаппарат ' || n else 'Demo table โต๊ะ Стол ' || n end,
    'Synthetic query-plan fixture', n % 50000,
    '10000000-0000-4000-8000-000000000001',
    case when n % 2 = 0 then '20000000-0000-4000-8000-000000000001'::uuid else '20000000-0000-4000-8000-000000000002'::uuid end
from generate_series(1, 10000) n;
-- Normalize the GIN pending list after this artificial bulk load. Otherwise a
-- fresh-load plan can favor another index before normal autovacuum maintenance.
select gin_clean_pending_list('marketplace.listings_active_text_idx');
analyze marketplace.listings;

set local role phuketsold_api;
-- Return narrow cards; the eventual API also joins one ready cover/first image
-- and reference labels in the same query rather than issuing N+1 requests.
explain (analyze, buffers)
select id, title, price_thb, area_id, category_id, published_at
from marketplace.listings
where listing_type = 'sell' and status = 'active' and hidden_at is null
  and expires_at > statement_timestamp()
order by published_at desc, id desc limit 20;

explain (analyze, buffers)
select id, title, price_thb, area_id, category_id
from marketplace.listings
where listing_type = 'sell' and status = 'active' and hidden_at is null
  and expires_at > statement_timestamp() and price_thb between 500 and 2500
order by price_thb, id limit 20;

explain (analyze, buffers)
select id, title, price_thb, area_id, category_id, published_at
from marketplace.listings
where listing_type = 'buy' and status = 'active' and hidden_at is null
  and expires_at > statement_timestamp()
  and lower(coalesce(title, '') || ' ' || description) like '%rarecamera%'
order by published_at desc, id desc limit 20;

-- Keyset continuation must use both columns, with the same filters as page one.
explain (analyze, buffers)
select id, title, price_thb, published_at
from marketplace.listings
where listing_type = 'sell' and status = 'active' and hidden_at is null
  and expires_at > statement_timestamp()
  and (published_at, id) < (statement_timestamp(), 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)
order by published_at desc, id desc limit 20;

do $$
begin
    if not exists (select 1 from marketplace.listings where status = 'active' and hidden_at is null
        and lower(coalesce(title, '') || ' ' || description) like '%กล้อง%')
       or not exists (select 1 from marketplace.listings where status = 'active' and hidden_at is null
        and lower(coalesce(title, '') || ' ' || description) like '%фотоаппарат%') then
        raise exception 'Thai or Russian substring search failed';
    end if;
end;
$$;
reset role;
rollback;

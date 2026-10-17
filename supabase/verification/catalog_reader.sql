-- Local only; called after a container/PG-version check by npm run api:check.
begin;
grant phuketsold_catalog_reader to current_user with inherit false, set true;

insert into marketplace.categories (id, slug, name_en, name_th, name_ru, is_active) values
    ('11000000-0000-4000-8000-000000000001', 'reader-hidden-category', 'Hidden', 'ซ่อน', 'Скрыто', false);
insert into marketplace.areas (id, slug, name_en, name_th, name_ru, is_active) values
    ('22000000-0000-4000-8000-000000000001', 'reader-hidden-area', 'Hidden', 'ซ่อน', 'Скрыто', false);
insert into marketplace.developments (id, area_id, slug, name_en, name_th, name_ru, kind, is_active) values
    ('33000000-0000-4000-8000-000000000001', '22000000-0000-4000-8000-000000000001',
     'reader-hidden-parent', 'Hidden parent', 'ซ่อน', 'Скрыто', 'village', true),
    ('33000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001',
     'reader-hidden-development', 'Hidden', 'ซ่อน', 'Скрыто', 'condominium', false);

set local role phuketsold_catalog_reader;
do $$
declare table_name text;
begin
    if exists (select 1 from marketplace.categories where not is_active)
       or exists (select 1 from marketplace.areas where not is_active)
       or exists (select 1 from marketplace.developments where not is_active or area_id = '22000000-0000-4000-8000-000000000001') then
        raise exception 'Inactive reference data leaked';
    end if;
    foreach table_name in array array['categories', 'areas', 'developments'] loop
        if has_table_privilege(current_user, 'marketplace.' || table_name, 'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') then
            raise exception 'Reader has write access to %', table_name;
        end if;
    end loop;
    foreach table_name in array array['profiles', 'listing_groups', 'listings', 'listing_images', 'listing_events'] loop
        begin
            execute format('select 1 from marketplace.%I limit 1', table_name);
            raise exception 'Reader has private inventory access to %', table_name;
        exception when insufficient_privilege then null;
        end;
    end loop;
    begin
        update marketplace.categories set name_en = 'Unauthorized';
        raise exception 'Reader updated catalog';
    exception when insufficient_privilege then null;
    end;
end $$;

reset role;
update marketplace.categories set is_active = false;
update marketplace.areas set is_active = false;
set local role phuketsold_catalog_reader;
do $$ begin
    if exists (select 1 from marketplace.categories) or exists (select 1 from marketplace.areas)
       or exists (select 1 from marketplace.developments) then
        raise exception 'Empty active catalog should return zero rows';
    end if;
end $$;
rollback;

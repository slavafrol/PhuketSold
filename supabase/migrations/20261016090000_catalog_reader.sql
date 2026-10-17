-- The first API slice only needs public reference data. Do not grant the wider
-- phuketsold_api inventory writer group to its local/hosted runtime login.
begin;

create role phuketsold_catalog_reader nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
grant usage on schema marketplace to phuketsold_catalog_reader;
grant select on marketplace.categories, marketplace.areas, marketplace.developments to phuketsold_catalog_reader;

create policy catalog_read on marketplace.categories for select to phuketsold_catalog_reader using (is_active);
create policy catalog_read on marketplace.areas for select to phuketsold_catalog_reader using (is_active);
create policy catalog_read on marketplace.developments for select to phuketsold_catalog_reader
    using (is_active and exists (
        select 1 from marketplace.areas where areas.id = developments.area_id and areas.is_active
    ));

commit;

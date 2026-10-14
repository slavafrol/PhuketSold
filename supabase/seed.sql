-- Synthetic catalog for disposable local development only. Never seed a hosted
-- project with this file. Production reference data needs separate curation.
begin;

insert into marketplace.categories (id, slug, name_en, name_th, name_ru, sort_order) values
    ('10000000-0000-4000-8000-000000000001', 'demo-furniture', 'Furniture (demo)', 'เฟอร์นิเจอร์ (ตัวอย่าง)', 'Мебель (демо)', 10),
    ('10000000-0000-4000-8000-000000000002', 'demo-electronics', 'Electronics (demo)', 'อุปกรณ์อิเล็กทรอนิกส์ (ตัวอย่าง)', 'Электроника (демо)', 20),
    ('10000000-0000-4000-8000-000000000003', 'demo-household', 'Household (demo)', 'ของใช้ในบ้าน (ตัวอย่าง)', 'Товары для дома (демо)', 30)
on conflict (id) do nothing;

insert into marketplace.areas (id, slug, name_en, name_th, name_ru, sort_order) values
    ('20000000-0000-4000-8000-000000000001', 'demo-west', 'Demo West', 'พื้นที่ตัวอย่างตะวันตก', 'Демо: запад', 10),
    ('20000000-0000-4000-8000-000000000002', 'demo-east', 'Demo East', 'พื้นที่ตัวอย่างตะวันออก', 'Демо: восток', 20)
on conflict (id) do nothing;

insert into marketplace.developments (id, area_id, slug, name_en, name_th, name_ru, kind) values
    ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
     'demo-condo', 'Demo Condo (fictional)', 'คอนโดตัวอย่าง (สมมติ)', 'Демо-кондоминиум (вымышленный)', 'condominium')
on conflict (id) do nothing;

commit;

-- Metadata-only default: preserve existing classifications and validation.
begin;

alter table marketplace.developments alter column kind set default 'development';

commit;

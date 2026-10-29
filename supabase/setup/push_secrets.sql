-- Run once in the Supabase SQL editor (Dashboard > SQL Editor > New query > Run).
-- Creates the address of the push function and a random shared secret in Vault.
-- Nobody needs to see or copy the secret: the database and the function both read it from Vault.
select vault.create_secret('https://xwdaygcezdbneoubimgv.supabase.co/functions/v1/send-push', 'push_function_url')
 where not exists (select 1 from vault.secrets where name = 'push_function_url');
select vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'push_hook_secret')
 where not exists (select 1 from vault.secrets where name = 'push_hook_secret');
select name, created_at from vault.secrets where name in ('push_function_url', 'push_hook_secret');

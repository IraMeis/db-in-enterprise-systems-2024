CREATE UNIQUE INDEX IF NOT EXISTS sys_user_login_unique_idx
ON public.sys_user USING btree (login) WHERE is_deleted = false;

CREATE UNIQUE INDEX IF NOT EXISTS sys_user_phone_unique_idx
ON public.sys_user USING btree (phone) WHERE is_deleted = false;

CREATE UNIQUE INDEX IF NOT EXISTS sys_user_email_unique_idx
ON public.sys_user USING btree (email) WHERE is_deleted = false;

CREATE UNIQUE INDEX IF NOT EXISTS sys_group_name_unique_idx
ON public.sys_group USING btree (name) WHERE is_deleted = false;

CREATE UNIQUE INDEX IF NOT EXISTS reservoir_name_unique_idx
ON public.reservoir USING btree (name) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS measurement_date_idx
ON public.measurement USING btree (date);

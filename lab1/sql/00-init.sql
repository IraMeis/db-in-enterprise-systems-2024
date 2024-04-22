CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

create table sys_user
(
    unique_id              bigserial    constraint sys_user_pkey primary key,
    uuid                   uuid                     default uuid_generate_v4()    not null,
    created_timestamp      timestamp with time zone default statement_timestamp() not null,
    modified_timestamp     timestamp with time zone default statement_timestamp() not null,
    is_deleted             boolean                  default false                 not null,

    login                  varchar                                                not null,
    password               varchar                                                not null,
    description            varchar,
    first_name             varchar,
    second_name            varchar,
    last_name              varchar,
    phone                  varchar,
    email                  varchar,
    is_online              boolean                  default false                 not null
);

create table sys_group
(
    unique_id              bigserial    constraint sys_group_pkey primary key,
    uuid                   uuid                     default uuid_generate_v4()    not null,
    created_timestamp      timestamp with time zone default statement_timestamp() not null,
    modified_timestamp     timestamp with time zone default statement_timestamp() not null,
    is_deleted             boolean                  default false                 not null,

    name                   varchar                                                not null,
    description            varchar

);

create table link_sys_user_sys_group
(
    unique_id              bigserial    constraint link_sys_user_sys_group_pkey primary key,
    sys_user_ref               bigint not null constraint link_sys_user_sys_group_sys_user_ref_fkey
        references sys_user
        on update restrict on delete restrict,
    sys_group_ref          bigint not null constraint link_sys_user_sys_group_sys_group_ref_fkey
        references sys_group
        on update restrict on delete restrict,
    is_primary             boolean                  default false                 not null,
    is_admin               boolean                  default false                 not null
);

create table token
(
    unique_id              bigserial    constraint token_pkey primary key,
    sys_user_ref               bigint not null constraint token_sys_user_ref_fkey
        references sys_user
        on update restrict on delete restrict,
    content                bytea not null
);

create table reservoir
(
    unique_id              bigserial    constraint reservoir_pkey primary key,
    uuid                   uuid                     default uuid_generate_v4()    not null,
    created_timestamp      timestamp with time zone default statement_timestamp() not null,
    modified_timestamp     timestamp with time zone default statement_timestamp() not null,
    is_deleted             boolean                  default false                 not null,

    name                   varchar                                                not null,
    description            varchar

);

create table measurement
(
    unique_id              bigserial    constraint measurement_pkey primary key,
    uuid                   uuid                     default uuid_generate_v4()    not null,
    created_timestamp      timestamp with time zone default statement_timestamp() not null,
    modified_timestamp     timestamp with time zone default statement_timestamp() not null,
    is_deleted             boolean                  default false                 not null,

    lon                    double precision,
    lat                    double precision,
    date timestamp with time zone not null,
    sys_user_ref           bigint not null constraint measurement_sys_user_ref_fkey
        references sys_user
        on update restrict on delete restrict,
    sys_group_ref          bigint not null constraint measurement_sys_group_ref_fkey
        references sys_group
        on update restrict on delete restrict,
    reservoir_ref      bigint not null constraint measurement_reservoir_ref_fkey
        references reservoir
        on update restrict on delete restrict,
    ph                    double precision,
    hardness              double precision,
    solids                double precision,
    chloramines           double precision,
    sulfate               double precision,
    conductivity          double precision,
    organic_carbon        double precision,
    trihalomethanes       double precision,
    turbidity             double precision
);

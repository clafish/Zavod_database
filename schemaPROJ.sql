---------------------- PEOPLE ----------------------

CREATE TABLE inspectors (
    inspector_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         text NOT NULL
);

CREATE TABLE operators (
    operator_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        text NOT NULL
);

CREATE TABLE customers (
    customer_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        text NOT NULL
);

---------------------- MATERIALS ----------------------

CREATE TABLE materials (
    material_id   int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title         text NOT NULL,
    unit          text NOT NULL CHECK (unit IN ('m', 'kg', 'amount', 'm2', 'm3')),
    available_qty numeric(12,3) NOT NULL DEFAULT 0 CHECK (available_qty >= 0)
);

---------------------- ORDER RECEIVING ----------------------

CREATE TABLE customer_order (
    customer_order_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id       int NOT NULL REFERENCES customers(customer_id),
    product_name      text NOT NULL,
    ordered_qty       int NOT NULL CHECK (ordered_qty > 0),
    accepted_at       timestamptz NOT NULL DEFAULT now(),
    status            text NOT NULL DEFAULT 'draft'
                      CHECK (status IN ('draft', 'confirmed', 'in_progress', 'done', 'cancelled'))
);

---------------------- SCHEMAS ----------------------

CREATE TABLE schemas (
    schema_id         int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_order_id int NOT NULL REFERENCES customer_order(customer_order_id),
    name              text NOT NULL,
    version_num       int NOT NULL DEFAULT 1 CHECK (version_num > 0),
    created_at        timestamptz NOT NULL DEFAULT now(),
    is_locked         boolean NOT NULL DEFAULT false,
    UNIQUE (customer_order_id, version_num)
);

CREATE TABLE schema_materials (
    schema_id   int NOT NULL REFERENCES schemas(schema_id),
    material_id int NOT NULL REFERENCES materials(material_id),
    qty_perunit numeric(12,3) NOT NULL CHECK (qty_perunit > 0),
    PRIMARY KEY (schema_id, material_id)
);

---------------------- PRODUCTION ----------------------

CREATE TABLE production_order (
    production_order_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    schema_id           int NOT NULL REFERENCES schemas(schema_id),
    root_order_id       int REFERENCES production_order(production_order_id),  -- NULL for the root order
    order_num           text NOT NULL UNIQUE,                                   -- 101, 101_1, 101_2 ...
    planned_qty         int NOT NULL CHECK (planned_qty > 0),
    status              text NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft', 'confirmed', 'in_progress', 'done', 'cancelled')),
    confirmed_at        timestamptz,
    CONSTRAINT chk_confirmed_at CHECK (
           (status = 'draft' AND confirmed_at IS NULL)
        OR (status IN ('confirmed', 'in_progress', 'done') AND confirmed_at IS NOT NULL)
        OR status = 'cancelled'
    )
);

CREATE TABLE production_order_component (
    production_order_id int NOT NULL REFERENCES production_order(production_order_id),
    material_id         int NOT NULL REFERENCES materials(material_id),
    reserved_qty        numeric(12,3) NOT NULL CHECK (reserved_qty > 0),
    PRIMARY KEY (production_order_id, material_id)
);

CREATE TABLE consumption_record (
    consumption_record_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    production_order_id   int NOT NULL,
    material_id           int NOT NULL,
    operator_id           int NOT NULL REFERENCES operators(operator_id),
    qty                   numeric(12,3) NOT NULL CHECK (qty > 0),
    recorded_at           timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (production_order_id, material_id)
        REFERENCES production_order_component(production_order_id, material_id)
);

CREATE TABLE production_record (
    production_record_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    production_order_id  int NOT NULL REFERENCES production_order(production_order_id),
    operator_id          int NOT NULL REFERENCES operators(operator_id),
    qty                  int NOT NULL CHECK (qty > 0),
    recorded_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE inspection (
    inspection_id       int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    production_order_id int NOT NULL REFERENCES production_order(production_order_id),
    inspector_id        int NOT NULL REFERENCES inspectors(inspector_id),
    accepted_qty        int NOT NULL CHECK (accepted_qty >= 0),
    inspected_at        timestamptz NOT NULL DEFAULT now()
);

---------------------- SCRAP ----------------------

CREATE TABLE scrap_record (
    scrap_record_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    inspection_id   int NOT NULL REFERENCES inspection(inspection_id),
    reason          text NOT NULL,
    qty             int NOT NULL CHECK (qty > 0)
);

---------------------- COMPLETION ----------------------

CREATE TABLE production_completion (
    production_order_id int PRIMARY KEY REFERENCES production_order(production_order_id),
    accepted_qty        int NOT NULL CHECK (accepted_qty >= 0),
    scrapped_qty        int NOT NULL CHECK (scrapped_qty >= 0),
    closed_at           timestamptz NOT NULL DEFAULT now(),
    note                text
);
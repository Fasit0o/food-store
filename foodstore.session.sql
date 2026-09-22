-- TP FOODSTORE - BASE DE DATOS I
-- DDL - PostgreSQL

-- 1. TIPO ENUM PARA FORMA DE PAGO
CREATE TYPE forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);

-- 2. TABLA CLIENTE
CREATE TABLE cliente (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    CONSTRAINT pk_cliente
        PRIMARY KEY (id),
    CONSTRAINT uq_cliente_email
        UNIQUE (email)
);

-- 3. TABLA CATEGORIA
CREATE TABLE categoria (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_categoria
        PRIMARY KEY (id),
    CONSTRAINT uq_categoria_nombre
        UNIQUE (nombre)
);

-- 4. TABLA PRODUCTO
CREATE TABLE producto (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(150) NOT NULL,
    precio NUMERIC(10,2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    categoria_id BIGINT NOT NULL,
    CONSTRAINT pk_producto
        PRIMARY KEY (id),
    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (categoria_id)
        REFERENCES categoria(id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_producto_precio
        CHECK (precio >= 0),
    CONSTRAINT ck_producto_stock
        CHECK (stock >= 0)
);

-- 5. TABLA PEDIDO
CREATE TABLE pedido (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    forma_pago forma_pago_enum NOT NULL,
    cliente_id BIGINT NOT NULL,
    CONSTRAINT pk_pedido
        PRIMARY KEY (id),
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (cliente_id)
        REFERENCES cliente(id)
        ON DELETE RESTRICT
);

-- 6. TABLA DETALLE_PEDIDO
CREATE TABLE detalle_pedido (
    pedido_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_detalle_pedido
        PRIMARY KEY (pedido_id, producto_id),
    CONSTRAINT fk_detalle_pedido_pedido
        FOREIGN KEY (pedido_id)
        REFERENCES pedido(id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_pedido_producto
        FOREIGN KEY (producto_id)
        REFERENCES producto(id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_detalle_pedido_cantidad
        CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_pedido_precio
        CHECK (precio_unitario >= 0)
);

-- 7. INDICES
CREATE INDEX idx_producto_categoria
    ON producto(categoria_id);

CREATE INDEX idx_pedido_cliente
    ON pedido(cliente_id);

CREATE INDEX idx_detalle_pedido_producto
    ON detalle_pedido(producto_id);

-- Procedimiento de baja lógica de producto

CREATE OR REPLACE PROCEDURE sp_desactivar_producto(
    p_producto_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM producto
        WHERE id = p_producto_id
    ) THEN
        RAISE EXCEPTION 'El producto con id % no existe', p_producto_id;
    END IF;

    UPDATE producto
    SET activo = FALSE
    WHERE id = p_producto_id;
END;
$$;
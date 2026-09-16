-- TP FOODSTORE - BASE DE DATOS I
-- DDL - PostgreSQL

CREATE TYPE forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);

CREATE TABLE cliente (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    CONSTRAINT pk_cliente PRIMARY KEY (id),
    CONSTRAINT uq_cliente_email UNIQUE (email)
);

CREATE TABLE categoria (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_categoria PRIMARY KEY (id),
    CONSTRAINT uq_categoria_nombre UNIQUE (nombre)
);

CREATE TABLE producto (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    nombre VARCHAR(150) NOT NULL,
    precio NUMERIC(10,2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    categoria_id BIGINT NOT NULL,
    CONSTRAINT pk_producto PRIMARY KEY (id),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id)
        REFERENCES categoria(id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_producto_precio CHECK (precio >= 0),
    CONSTRAINT ck_producto_stock CHECK (stock >= 0)
);

CREATE TABLE pedido (
    id BIGINT GENERATED ALWAYS AS IDENTITY,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    forma_pago forma_pago_enum NOT NULL,
    cliente_id BIGINT NOT NULL,
    CONSTRAINT pk_pedido PRIMARY KEY (id),
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (cliente_id)
        REFERENCES cliente(id)
        ON DELETE RESTRICT
);

CREATE TABLE detalle_pedido (
    pedido_id BIGINT NOT NULL,
    producto_id BIGINT NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_detalle_pedido PRIMARY KEY (pedido_id, producto_id),
    CONSTRAINT fk_detalle_pedido_pedido FOREIGN KEY (pedido_id)
        REFERENCES pedido(id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_pedido_producto FOREIGN KEY (producto_id)
        REFERENCES producto(id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_detalle_pedido_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_pedido_precio CHECK (precio_unitario >= 0)
);

CREATE INDEX idx_producto_categoria ON producto(categoria_id);
CREATE INDEX idx_pedido_cliente ON pedido(cliente_id);
CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido(producto_id);

--
-- PostgreSQL database dump
--

\restrict jMSDjK9d4oDpawJC4HeJJ7Vh6ZGQgXeuY8BsXc1QPXvVug4qflyxfaqeNxDRnvW

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: categoria; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.categoria OVERRIDING SYSTEM VALUE VALUES (1, 'Categoria Prueba', true);


--
-- Data for Name: cliente; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.cliente OVERRIDING SYSTEM VALUE VALUES (1, 'Cliente', 'Prueba', 'cliente.prueba@foodstore.test');


--
-- Data for Name: pedido; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.pedido OVERRIDING SYSTEM VALUE VALUES (3, '2026-09-16', 'EFECTIVO', 1);


--
-- Data for Name: producto; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.producto OVERRIDING SYSTEM VALUE VALUES (2, 'Producto Inactivo', 200.00, 10, false, 1);
INSERT INTO public.producto OVERRIDING SYSTEM VALUE VALUES (1, 'Producto Activo', 100.00, 30, true, 1);


--
-- Data for Name: detalle_pedido; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.detalle_pedido VALUES (3, 1, 2, 100.00);


--
-- Name: categoria_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categoria_id_seq', 1, true);


--
-- Name: cliente_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cliente_id_seq', 1, true);


--
-- Name: pedido_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pedido_id_seq', 3, true);


--
-- Name: producto_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.producto_id_seq', 3, true);


--
-- PostgreSQL database dump complete
--

\unrestrict jMSDjK9d4oDpawJC4HeJJ7Vh6ZGQgXeuY8BsXc1QPXvVug4qflyxfaqeNxDRnvW

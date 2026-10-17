-- === Етап 1: DDL (Створення схеми та таблиць) ===

DROP SCHEMA IF EXISTS tourism CASCADE;
CREATE SCHEMA tourism;
SET search_path TO tourism, public;

CREATE TABLE roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(255)
);

CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    role_id INT NOT NULL REFERENCES roles(role_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    email VARCHAR(150) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(30),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    CONSTRAINT chk_users_soft_delete CHECK (
        (is_deleted = FALSE AND deleted_at IS NULL) OR
        (is_deleted = TRUE AND deleted_at IS NOT NULL)
    )
);

CREATE TABLE tourist_profiles (
    user_id BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    passport_number VARCHAR(30) NOT NULL UNIQUE,
    citizenship CHAR(2) NOT NULL,
    birth_date DATE NOT NULL CHECK (birth_date < CURRENT_DATE AND birth_date > DATE '1900-01-01'),
    emergency_contact VARCHAR(150),
    preferences JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE countries (
    country_id SERIAL PRIMARY KEY,
    iso_code CHAR(2) NOT NULL UNIQUE,
    country_name VARCHAR(100) NOT NULL UNIQUE,
    visa_required BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE cities (
    city_id SERIAL PRIMARY KEY,
    country_id INT NOT NULL REFERENCES countries(country_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    city_name VARCHAR(100) NOT NULL,
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    CONSTRAINT uq_cities_country_name UNIQUE (country_id, city_name)
);

CREATE TABLE locations (
    location_id BIGSERIAL PRIMARY KEY,
    city_id INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    parent_location_id BIGINT REFERENCES locations(location_id) ON DELETE SET NULL ON UPDATE CASCADE,
    location_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL CHECK (category IN ('Park', 'Museum', 'Monument', 'Beach', 'Mountain', 'District')),
    description TEXT,
    CONSTRAINT chk_locations_no_self_parent CHECK (parent_location_id IS NULL OR parent_location_id <> location_id)
);

CREATE TABLE agencies (
    agency_id BIGSERIAL PRIMARY KEY,
    agency_name VARCHAR(150) NOT NULL,
    license_number VARCHAR(50) NOT NULL UNIQUE,
    contact_email VARCHAR(150) NOT NULL,
    phone VARCHAR(30) NOT NULL,
    rating NUMERIC(3,2) NOT NULL DEFAULT 5.00 CHECK (rating >= 0.00 AND rating <= 5.00),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE hotels (
    hotel_id BIGSERIAL PRIMARY KEY,
    city_id INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    hotel_name VARCHAR(150) NOT NULL,
    stars SMALLINT NOT NULL CHECK (stars BETWEEN 1 AND 5),
    address VARCHAR(255) NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE room_types (
    room_type_id BIGSERIAL PRIMARY KEY,
    hotel_id BIGINT NOT NULL REFERENCES hotels(hotel_id) ON DELETE CASCADE ON UPDATE CASCADE,
    type_name VARCHAR(100) NOT NULL,
    capacity SMALLINT NOT NULL CHECK (capacity > 0 AND capacity <= 10),
    base_price_per_night NUMERIC(10,2) NOT NULL CHECK (base_price_per_night >= 0)
);

CREATE TABLE transport_providers (
    provider_id SERIAL PRIMARY KEY,
    provider_name VARCHAR(150) NOT NULL UNIQUE,
    transport_type VARCHAR(20) NOT NULL CHECK (transport_type IN ('Air', 'Bus', 'Train', 'Sea')),
    contact_phone VARCHAR(30)
);

CREATE TABLE tours (
    tour_id BIGSERIAL PRIMARY KEY,
    agency_id BIGINT NOT NULL REFERENCES agencies(agency_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    title VARCHAR(200) NOT NULL,
    tour_code VARCHAR(30) NOT NULL UNIQUE,
    base_price NUMERIC(12,2) NOT NULL CHECK (base_price > 0),
    duration_days SMALLINT NOT NULL CHECK (duration_days > 0),
    max_group_size SMALLINT NOT NULL CHECK (max_group_size > 0),
    tags TEXT[] NOT NULL DEFAULT '{}'::text[],
    status VARCHAR(20) NOT NULL DEFAULT 'Active' CHECK (status IN ('Draft', 'Active', 'Archived')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE tour_departures (
    departure_id BIGSERIAL PRIMARY KEY,
    tour_id BIGINT NOT NULL REFERENCES tours(tour_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    provider_id INT REFERENCES transport_providers(provider_id) ON DELETE SET NULL ON UPDATE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    price_override NUMERIC(12,2) CHECK (price_override IS NULL OR price_override > 0),
    total_seats SMALLINT NOT NULL CHECK (total_seats > 0),
    available_seats SMALLINT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Scheduled' CHECK (status IN ('Scheduled', 'Guaranteed', 'Cancelled', 'Completed')),
    CONSTRAINT chk_departures_dates CHECK (end_date > start_date),
    CONSTRAINT chk_departures_seats CHECK (available_seats >= 0 AND available_seats <= total_seats)
);

CREATE TABLE tour_itinerary_stages (
    stage_id BIGSERIAL PRIMARY KEY,
    tour_id BIGINT NOT NULL REFERENCES tours(tour_id) ON DELETE CASCADE ON UPDATE CASCADE,
    day_number SMALLINT NOT NULL CHECK (day_number > 0),
    location_id BIGINT NOT NULL REFERENCES locations(location_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    room_type_id BIGINT REFERENCES room_types(room_type_id) ON DELETE SET NULL ON UPDATE CASCADE,
    stage_title VARCHAR(150) NOT NULL,
    description TEXT,
    CONSTRAINT uq_tour_stage_day UNIQUE (tour_id, day_number)
);

CREATE TABLE excursions (
    excursion_id BIGSERIAL PRIMARY KEY,
    location_id BIGINT NOT NULL REFERENCES locations(location_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    guide_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL ON UPDATE CASCADE,
    title VARCHAR(150) NOT NULL,
    duration_hours NUMERIC(4,1) NOT NULL CHECK (duration_hours > 0),
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE promotions (
    promotion_id BIGSERIAL PRIMARY KEY,
    promo_code VARCHAR(30) NOT NULL UNIQUE,
    discount_percent NUMERIC(5,2) NOT NULL CHECK (discount_percent > 0 AND discount_percent <= 90),
    valid_from DATE NOT NULL,
    valid_to DATE NOT NULL,
    max_uses INT NOT NULL CHECK (max_uses > 0),
    current_uses INT NOT NULL DEFAULT 0 CHECK (current_uses >= 0 AND current_uses <= max_uses),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_promotions_dates CHECK (valid_to >= valid_from)
);

CREATE TABLE bookings (
    booking_id BIGSERIAL PRIMARY KEY,
    booking_number VARCHAR(40) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    departure_id BIGINT NOT NULL REFERENCES tour_departures(departure_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    promotion_id BIGINT REFERENCES promotions(promotion_id) ON DELETE SET NULL ON UPDATE CASCADE,
    participants_count SMALLINT NOT NULL CHECK (participants_count > 0),
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    booking_status VARCHAR(20) NOT NULL DEFAULT 'Pending' CHECK (booking_status IN ('Pending', 'Confirmed', 'Cancelled', 'Completed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE booking_excursions (
    booking_id BIGINT NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE ON UPDATE CASCADE,
    excursion_id BIGINT NOT NULL REFERENCES excursions(excursion_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    attendees_count SMALLINT NOT NULL CHECK (attendees_count > 0),
    fixed_price NUMERIC(10,2) NOT NULL CHECK (fixed_price >= 0),
    PRIMARY KEY (booking_id, excursion_id)
);

CREATE TABLE payments (
    payment_id BIGSERIAL PRIMARY KEY,
    booking_id BIGINT NOT NULL REFERENCES bookings(booking_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency CHAR(3) NOT NULL DEFAULT 'USD',
    payment_method VARCHAR(30) NOT NULL CHECK (payment_method IN ('Card', 'BankTransfer', 'ApplePay', 'GooglePay')),
    external_tx_ref VARCHAR(100) NOT NULL UNIQUE,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'Completed' CHECK (payment_status IN ('Pending', 'Completed', 'Failed', 'Refunded')),
    paid_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    updated_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE reviews (
    review_id BIGSERIAL PRIMARY KEY,
    booking_id BIGINT NOT NULL UNIQUE REFERENCES bookings(booking_id) ON DELETE CASCADE ON UPDATE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    tour_id BIGINT NOT NULL REFERENCES tours(tour_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    deleted_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(64) NOT NULL,
    record_id BIGINT NOT NULL,
    operation_type VARCHAR(20) NOT NULL CHECK (operation_type IN ('INSERT', 'UPDATE', 'SOFT_DELETE', 'RESTORE')),
    changed_by_user_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    old_values JSONB,
    new_values jsonb
);

-- === Етап 2: Бізнес-логіка (Функції, Тригери, Представлення, Процедури) ===

SET search_path TO tourism, public;

CREATE OR REPLACE FUNCTION fn_get_current_actor_id()
RETURNS BIGINT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_val TEXT;
BEGIN
    v_val := current_setting('app.current_user_id', true);
    IF v_val IS NULL OR v_val = '' THEN
        RETURN NULL;
    END IF;
    RETURN v_val::BIGINT;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION fn_trg_audit_and_soft_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor_id BIGINT;
    v_op_type VARCHAR(20);
    v_record_id BIGINT;
BEGIN
    v_actor_id := COALESCE(fn_get_current_actor_id(), NEW.updated_by_user_id);

    IF TG_TABLE_NAME = 'users' THEN v_record_id := NEW.user_id;
    ELSIF TG_TABLE_NAME = 'agencies' THEN v_record_id := NEW.agency_id;
    ELSIF TG_TABLE_NAME = 'tours' THEN v_record_id := NEW.tour_id;
    ELSIF TG_TABLE_NAME = 'bookings' THEN v_record_id := NEW.booking_id;
    ELSIF TG_TABLE_NAME = 'payments' THEN v_record_id := NEW.payment_id;
    END IF;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (table_name, record_id, operation_type, changed_by_user_id, changed_at, old_values, new_values)
        VALUES (TG_TABLE_NAME, v_record_id, 'INSERT', v_actor_id, NOW(), NULL, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        NEW.updated_at := NOW();
        NEW.updated_by_user_id := v_actor_id;
        v_op_type := 'UPDATE';

        IF TG_TABLE_NAME IN ('users', 'agencies', 'tours', 'bookings') THEN
            IF OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE THEN
                NEW.deleted_at := COALESCE(NEW.deleted_at, NOW());
                NEW.deleted_by_user_id := COALESCE(v_actor_id, NEW.deleted_by_user_id);
                v_op_type := 'SOFT_DELETE';
            ELSIF OLD.is_deleted = TRUE AND NEW.is_deleted = FALSE THEN
                NEW.deleted_at := NULL;
                NEW.deleted_by_user_id := NULL;
                v_op_type := 'RESTORE';
            END IF;
        END IF;

        INSERT INTO audit_logs (table_name, record_id, operation_type, changed_by_user_id, changed_at, old_values, new_values)
        VALUES (TG_TABLE_NAME, v_record_id, v_op_type, v_actor_id, NOW(), to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_users
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION fn_trg_audit_and_soft_delete();

CREATE TRIGGER trg_audit_agencies
BEFORE INSERT OR UPDATE ON agencies
FOR EACH ROW EXECUTE FUNCTION fn_trg_audit_and_soft_delete();

CREATE TRIGGER trg_audit_tours
BEFORE INSERT OR UPDATE ON tours
FOR EACH ROW EXECUTE FUNCTION fn_trg_audit_and_soft_delete();

CREATE TRIGGER trg_audit_bookings
BEFORE INSERT OR UPDATE ON bookings
FOR EACH ROW EXECUTE FUNCTION fn_trg_audit_and_soft_delete();

CREATE TRIGGER trg_audit_payments
BEFORE INSERT OR UPDATE ON payments
FOR EACH ROW EXECUTE FUNCTION fn_trg_audit_and_soft_delete();

CREATE OR REPLACE FUNCTION fn_trg_validate_review()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
    v_booking_user BIGINT;
    v_is_deleted BOOLEAN;
BEGIN
    SELECT booking_status, user_id, is_deleted
    INTO v_status, v_booking_user, v_is_deleted
    FROM bookings
    WHERE booking_id = NEW.booking_id;

    IF NOT FOUND OR v_is_deleted THEN
        RAISE EXCEPTION 'Booking % does not exist or is deleted.', NEW.booking_id;
    END IF;

    IF v_booking_user <> NEW.user_id THEN
        RAISE EXCEPTION 'User % is not the owner of booking %.', NEW.user_id, NEW.booking_id;
    END IF;

    IF v_status NOT IN ('Confirmed', 'Completed') THEN
        RAISE EXCEPTION 'Cannot post review for booking % with status %.', NEW.booking_id, v_status;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_review
BEFORE INSERT ON reviews
FOR EACH ROW EXECUTE FUNCTION fn_trg_validate_review();

CREATE OR REPLACE VIEW vw_active_tour_offers AS
SELECT
    t.tour_id,
    t.tour_code,
    t.title AS tour_title,
    a.agency_name,
    td.departure_id,
    td.start_date,
    td.end_date,
    COALESCE(td.price_override, t.base_price) AS effective_price,
    t.duration_days,
    td.available_seats,
    td.total_seats,
    t.tags,
    COALESCE(ROUND(AVG(r.rating) FILTER (WHERE r.is_deleted = FALSE), 2), 0.00) AS avg_rating
FROM tours t
JOIN agencies a ON a.agency_id = t.agency_id AND a.is_deleted = FALSE
JOIN tour_departures td ON td.tour_id = t.tour_id
LEFT JOIN reviews r ON r.tour_id = t.tour_id
WHERE t.is_deleted = FALSE
  AND t.status = 'Active'
  AND td.status IN ('Scheduled', 'Guaranteed')
  AND td.available_seats > 0
GROUP BY t.tour_id, a.agency_name, td.departure_id;

CREATE OR REPLACE VIEW vw_booking_details AS
SELECT
    b.booking_id,
    b.booking_number,
    b.user_id,
    u.full_name AS tourist_name,
    u.email AS tourist_email,
    t.tour_id,
    t.title AS tour_title,
    td.departure_id,
    td.start_date,
    td.end_date,
    b.participants_count,
    b.total_amount,
    COALESCE(SUM(p.amount) FILTER (WHERE p.payment_status = 'Completed'), 0.00) AS paid_amount,
    b.booking_status,
    b.created_at,
    b.updated_at,
    b.updated_by_user_id
FROM bookings b
JOIN users u ON u.user_id = b.user_id AND u.is_deleted = FALSE
JOIN tour_departures td ON td.departure_id = b.departure_id
JOIN tours t ON t.tour_id = td.tour_id
LEFT JOIN payments p ON p.booking_id = b.booking_id
WHERE b.is_deleted = FALSE
GROUP BY b.booking_id, u.full_name, u.email, t.tour_id, t.title, td.departure_id;

CREATE OR REPLACE VIEW vw_payment_registry AS
SELECT
    p.payment_id,
    p.external_tx_ref,
    p.booking_id,
    b.booking_number,
    u.full_name AS payer_name,
    t.title AS tour_title,
    p.amount,
    p.currency,
    p.payment_method,
    p.payment_status,
    p.paid_at
FROM payments p
JOIN bookings b ON b.booking_id = p.booking_id
JOIN users u ON u.user_id = b.user_id
JOIN tour_departures td ON td.departure_id = b.departure_id
JOIN tours t ON t.tour_id = td.tour_id;

CREATE OR REPLACE VIEW vw_agency_statistics AS
SELECT
    a.agency_id,
    a.agency_name,
    COUNT(DISTINCT t.tour_id) FILTER (WHERE t.is_deleted = FALSE) AS active_tours_count,
    COUNT(DISTINCT b.booking_id) FILTER (WHERE b.is_deleted = FALSE AND b.booking_status IN ('Confirmed', 'Completed')) AS confirmed_bookings_count,
    COALESCE(SUM(b.participants_count) FILTER (WHERE b.is_deleted = FALSE AND b.booking_status IN ('Confirmed', 'Completed')), 0) AS total_tourists_served,
    COALESCE(SUM(p.amount) FILTER (WHERE p.payment_status = 'Completed' AND b.is_deleted = FALSE), 0.00) AS total_revenue
FROM agencies a
LEFT JOIN tours t ON t.agency_id = a.agency_id
LEFT JOIN tour_departures td ON td.tour_id = t.tour_id
LEFT JOIN bookings b ON b.departure_id = td.departure_id
LEFT JOIN payments p ON p.booking_id = b.booking_id
WHERE a.is_deleted = FALSE
GROUP BY a.agency_id, a.agency_name;

CREATE OR REPLACE VIEW vw_deleted_records_registry AS
SELECT 'users' AS entity_type, user_id AS record_id, email AS identifier, deleted_at, deleted_by_user_id FROM users WHERE is_deleted = TRUE
UNION ALL
SELECT 'agencies', agency_id, agency_name, deleted_at, deleted_by_user_id FROM agencies WHERE is_deleted = TRUE
UNION ALL
SELECT 'tours', tour_id, tour_code || ': ' || title, deleted_at, deleted_by_user_id FROM tours WHERE is_deleted = TRUE
UNION ALL
SELECT 'bookings', booking_id, booking_number, deleted_at, deleted_by_user_id FROM bookings WHERE is_deleted = TRUE
UNION ALL
SELECT 'reviews', review_id, 'Booking #' || booking_id::text, deleted_at, deleted_by_user_id FROM reviews WHERE is_deleted = TRUE;

CREATE OR REPLACE FUNCTION fn_search_tours(
    p_country_iso CHAR(2) DEFAULT NULL,
    p_min_date DATE DEFAULT NULL,
    p_max_price NUMERIC DEFAULT NULL,
    p_tag TEXT DEFAULT NULL
)
RETURNS TABLE (
    tour_id BIGINT,
    tour_code VARCHAR,
    tour_title VARCHAR,
    departure_id BIGINT,
    start_date DATE,
    end_date DATE,
    effective_price NUMERIC,
    available_seats SMALLINT,
    tags TEXT[]
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        v.tour_id,
        v.tour_code,
        v.tour_title,
        v.departure_id,
        v.start_date,
        v.end_date,
        v.effective_price,
        v.available_seats,
        v.tags
    FROM vw_active_tour_offers v
    LEFT JOIN tour_itinerary_stages s ON s.tour_id = v.tour_id
    LEFT JOIN locations l ON l.location_id = s.location_id
    LEFT JOIN cities c ON c.city_id = l.city_id
    LEFT JOIN countries cnt ON cnt.country_id = c.country_id
    WHERE (p_country_iso IS NULL OR cnt.iso_code = p_country_iso)
      AND (p_min_date IS NULL OR v.start_date >= p_min_date)
      AND (p_max_price IS NULL OR v.effective_price <= p_max_price)
      AND (p_tag IS NULL OR v.tags @> ARRAY[p_tag]::text[])
    ORDER BY v.start_date, v.effective_price;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_create_booking(
    IN p_actor_user_id BIGINT,
    IN p_tourist_user_id BIGINT,
    IN p_departure_id BIGINT,
    IN p_participants_count SMALLINT,
    IN p_promo_code VARCHAR,
    IN p_excursion_id BIGINT,
    OUT o_booking_id BIGINT,
    OUT o_booking_number VARCHAR,
    OUT o_total_amount NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_unit_price NUMERIC(12,2);
    v_avail_seats SMALLINT;
    v_dep_status VARCHAR(20);
    v_tour_deleted BOOLEAN;
    v_promo_id BIGINT := NULL;
    v_discount_pct NUMERIC(5,2) := 0;
    v_excursion_price NUMERIC(10,2) := 0;
BEGIN
    PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

    SELECT COALESCE(td.price_override, t.base_price), td.available_seats, td.status, t.is_deleted
    INTO v_unit_price, v_avail_seats, v_dep_status, v_tour_deleted
    FROM tour_departures td
    JOIN tours t ON t.tour_id = td.tour_id
    WHERE td.departure_id = p_departure_id
    FOR UPDATE OF td;

    IF NOT FOUND OR v_tour_deleted THEN
        RAISE EXCEPTION 'Departure % not found or tour is deleted.', p_departure_id;
    END IF;

    IF v_dep_status NOT IN ('Scheduled', 'Guaranteed') THEN
        RAISE EXCEPTION 'Departure % is not open for booking (status: %).', p_departure_id, v_dep_status;
    END IF;

    IF v_avail_seats < p_participants_count THEN
        RAISE EXCEPTION 'Insufficient seats for departure %. Requested: %, Available: %.', p_departure_id, p_participants_count, v_avail_seats;
    END IF;

    IF p_promo_code IS NOT NULL AND p_promo_code <> '' THEN
        SELECT promotion_id, discount_percent
        INTO v_promo_id, v_discount_pct
        FROM promotions
        WHERE promo_code = p_promo_code
          AND is_active = TRUE
          AND CURRENT_DATE BETWEEN valid_from AND valid_to
          AND current_uses < max_uses
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Promo code % is invalid or expired.', p_promo_code;
        END IF;

        UPDATE promotions SET current_uses = current_uses + 1 WHERE promotion_id = v_promo_id;
    END IF;

    o_total_amount := ROUND((v_unit_price * p_participants_count) * (1 - v_discount_pct / 100.0), 2);

    IF p_excursion_id IS NOT NULL THEN
        SELECT price INTO v_excursion_price
        FROM excursions
        WHERE excursion_id = p_excursion_id AND is_deleted = FALSE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Excursion % not found or deleted.', p_excursion_id;
        END IF;

        o_total_amount := o_total_amount + (v_excursion_price * p_participants_count);
    END IF;

    o_booking_number := 'BK-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(nextval('bookings_booking_id_seq')::text, 5, '0');
    o_booking_id := currval('bookings_booking_id_seq');

    INSERT INTO bookings (
        booking_id, booking_number, user_id, departure_id, promotion_id,
        participants_count, total_amount, booking_status, updated_by_user_id
    )
    VALUES (
        o_booking_id, o_booking_number, p_tourist_user_id, p_departure_id, v_promo_id,
        p_participants_count, o_total_amount, 'Pending', p_actor_user_id
    );

    IF p_excursion_id IS NOT NULL THEN
        INSERT INTO booking_excursions (booking_id, excursion_id, attendees_count, fixed_price)
        VALUES (o_booking_id, p_excursion_id, p_participants_count, v_excursion_price);
    END IF;

    UPDATE tour_departures
    SET available_seats = available_seats - p_participants_count
    WHERE departure_id = p_departure_id;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_register_payment(
    IN p_actor_user_id BIGINT,
    IN p_booking_id BIGINT,
    IN p_amount NUMERIC,
    IN p_payment_method VARCHAR,
    IN p_external_tx_ref VARCHAR,
    OUT o_payment_id BIGINT,
    OUT o_new_booking_status VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_amount NUMERIC(12,2);
    v_paid_so_far NUMERIC(12,2);
    v_is_deleted BOOLEAN;
BEGIN
    PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

    SELECT total_amount, booking_status, is_deleted
    INTO v_total_amount, o_new_booking_status, v_is_deleted
    FROM bookings
    WHERE booking_id = p_booking_id
    FOR UPDATE;

    IF NOT FOUND OR v_is_deleted THEN
        RAISE EXCEPTION 'Booking % does not exist or is deleted.', p_booking_id;
    END IF;

    INSERT INTO payments (
        booking_id, amount, currency, payment_method, external_tx_ref,
        payment_status, paid_at, updated_by_user_id
    )
    VALUES (
        p_booking_id, p_amount, 'USD', p_payment_method, p_external_tx_ref,
        'Completed', NOW(), p_actor_user_id
    )
    RETURNING payment_id INTO o_payment_id;

    SELECT COALESCE(SUM(amount), 0)
    INTO v_paid_so_far
    FROM payments
    WHERE booking_id = p_booking_id AND payment_status = 'Completed';

    IF v_paid_so_far >= v_total_amount AND o_new_booking_status = 'Pending' THEN
        o_new_booking_status := 'Confirmed';
        UPDATE bookings
        SET booking_status = o_new_booking_status,
            updated_by_user_id = p_actor_user_id
        WHERE booking_id = p_booking_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_soft_delete_tour(
    IN p_actor_user_id BIGINT,
    IN p_tour_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_active_bookings INT;
BEGIN
    PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

    SELECT COUNT(*)
    INTO v_active_bookings
    FROM bookings b
    JOIN tour_departures td ON td.departure_id = b.departure_id
    WHERE td.tour_id = p_tour_id
      AND b.is_deleted = FALSE
      AND b.booking_status IN ('Pending', 'Confirmed');

    IF v_active_bookings > 0 THEN
        RAISE EXCEPTION 'Cannot soft-delete tour % because it has % active bookings.', p_tour_id, v_active_bookings;
    END IF;

    UPDATE tours
    SET is_deleted = TRUE,
        status = 'Archived',
        updated_by_user_id = p_actor_user_id
    WHERE tour_id = p_tour_id AND is_deleted = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tour % not found or already deleted.', p_tour_id;
    END IF;
END;
$$;

CREATE OR REPLACE PROCEDURE sp_restore_soft_deleted_record(
    IN p_actor_user_id BIGINT,
    IN p_entity_name VARCHAR,
    IN p_record_id BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM set_config('app.current_user_id', p_actor_user_id::text, true);

    IF p_entity_name = 'tours' THEN
        UPDATE tours
        SET is_deleted = FALSE, status = 'Active', updated_by_user_id = p_actor_user_id
        WHERE tour_id = p_record_id AND is_deleted = TRUE;
    ELSIF p_entity_name = 'bookings' THEN
        UPDATE bookings
        SET is_deleted = FALSE, updated_by_user_id = p_actor_user_id
        WHERE booking_id = p_record_id AND is_deleted = TRUE;
    ELSIF p_entity_name = 'users' THEN
        UPDATE users
        SET is_deleted = FALSE, updated_by_user_id = p_actor_user_id
        WHERE user_id = p_record_id AND is_deleted = TRUE;
    ELSE
        RAISE EXCEPTION 'Unsupported entity % for restore operation.', p_entity_name;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Record % in % was not found in deleted state.', p_record_id, p_entity_name;
    END IF;
END;
$$;

-- === Етап 3: Оптимізація (Індекси) ===

SET search_path TO tourism, public;

CREATE UNIQUE INDEX idx_users_email_active_uq
ON users (LOWER(email))
WHERE is_deleted = FALSE;

CREATE INDEX idx_tours_active_covering
ON tours (agency_id, base_price)
INCLUDE (title, tour_code, duration_days)
WHERE is_deleted = FALSE AND status = 'Active';

CREATE INDEX idx_departures_tour_dates
ON tour_departures (tour_id, start_date, status)
WHERE available_seats > 0;

CREATE INDEX idx_bookings_user_status
ON bookings (user_id, booking_status)
WHERE is_deleted = FALSE;

CREATE INDEX idx_tours_tags_gin
ON tours USING GIN (tags);

CREATE INDEX idx_profiles_preferences_gin
ON tourist_profiles USING GIN (preferences jsonb_path_ops);

CREATE INDEX idx_payments_paid_at_brin
ON payments USING BRIN (paid_at);

-- === Етап 4: Наповнення бази (Тестові дані) ===

SET search_path TO tourism, public;

INSERT INTO roles (role_name, description) VALUES
('Admin', 'System administrator with full access and restore privileges'),
('AgencyManager', 'Tour operator manager'),
('Guide', 'Certified local excursion guide'),
('Tourist', 'Registered customer');

INSERT INTO users (role_id, email, password_hash, full_name, phone) VALUES
(1, 'admin@tourism.ua', 'hash_adm_1', 'Olena Kovalenko', '+380501112233'),
(2, 'manager@alpinetours.ua', 'hash_mgr_1', 'Dmytro Bondar', '+380672223344'),
(3, 'guide.marco@rome.it', 'hash_gde_1', 'Marco Rossi', '+3906112233'),
(4, 'nikita.student@knu.ua', 'hash_usr_1', 'Nikita Slobozhanin', '+380934445566'),
(4, 'anna.melnyk@gmail.com', 'hash_usr_2', 'Anna Melnyk', '+380975556677');

INSERT INTO tourist_profiles (user_id, passport_number, citizenship, birth_date, emergency_contact, preferences) VALUES
(4, 'FE123456', 'UA', '2004-05-14', '+380509998877', '{"seat": "window", "diet": "regular", "interests": ["mountains", "history"]}'::jsonb),
(5, 'GH654321', 'UA', '1999-11-20', '+380678887766', '{"seat": "aisle", "diet": "vegetarian", "interests": ["sea", "gastronomy"]}'::jsonb);

INSERT INTO countries (iso_code, country_name, visa_required) VALUES
('UA', 'Ukraine', FALSE),
('IT', 'Italy', FALSE),
('CH', 'Switzerland', FALSE);

INSERT INTO cities (country_id, city_name, timezone) VALUES
(1, 'Yaremche', 'Europe/Kyiv'),
(2, 'Rome', 'Europe/Rome'),
(3, 'Zermatt', 'Europe/Zurich');

INSERT INTO locations (city_id, parent_location_id, location_name, category, description) VALUES
(1, NULL, 'Carpathian National Park', 'Park', 'Main biosphere reserve in Ivano-Frankivsk region'),
(1, 1, 'Probiy Waterfall', 'Monument', 'Picturesque cascade waterfall on the Prut River'),
(2, NULL, 'Historic Center of Rome', 'District', 'Ancient Roman historical area'),
(2, 3, 'Colosseum Amphitheatre', 'Monument', 'Flavian Amphitheatre in the center of Rome'),
(3, NULL, 'Matterhorn Glacier Paradise', 'Mountain', 'High alpine mountain station');

INSERT INTO agencies (agency_name, license_number, contact_email, phone, rating, updated_by_user_id) VALUES
('Carpathian Horizons LLC', 'LIC-UA-2026-01', 'info@carpathian.ua', '+380441234567', 4.90, 1),
('EuroVistas Travel', 'LIC-EU-2026-02', 'booking@eurovistas.eu', '+380447654321', 4.85, 1);

INSERT INTO hotels (city_id, hotel_name, stars, address) VALUES
(1, 'Edelweiss Mountain Resort', 4, 'Svobody St 14, Yaremche'),
(2, 'Hotel Artemide Roma', 4, 'Via Nazionale 22, Rome'),
(3, 'Alpine Matterhorn Lodge', 5, 'Bahnhofstrasse 45, Zermatt');

INSERT INTO room_types (hotel_id, type_name, capacity, base_price_per_night) VALUES
(1, 'Standard Twin Mountain View', 2, 85.00),
(2, 'Superior Double', 2, 160.00),
(3, 'Panoramic Chalet Suite', 2, 320.00);

INSERT INTO transport_providers (provider_name, transport_type, contact_phone) VALUES
('Ukrzaliznytsia Express', 'Train', '+380800503111'),
('SkyUp Charter', 'Air', '+380443334455'),
('EuroLines Coach', 'Bus', '+380449990011');

INSERT INTO tours (agency_id, title, tour_code, base_price, duration_days, max_group_size, tags, status, updated_by_user_id) VALUES
(1, 'Carpathian Peaks & Waterfalls', 'UA-CARP-01', 350.00, 5, 20, ARRAY['mountains', 'hiking', 'nature'], 'Active', 2),
(2, 'Eternal Rome & Vatican Secrets', 'IT-ROME-02', 890.00, 6, 15, ARRAY['history', 'architecture', 'gastronomy'], 'Active', 2),
(2, 'Swiss Alps Matterhorn Expedition', 'CH-ALPS-03', 1450.00, 7, 12, ARRAY['mountains', 'luxury', 'ski'], 'Active', 2);

INSERT INTO tour_departures (tour_id, provider_id, start_date, end_date, price_override, total_seats, available_seats, status) VALUES
(1, 1, '2026-11-10', '2026-11-15', NULL, 20, 20, 'Guaranteed'),
(2, 2, '2026-11-20', '2026-11-26', 850.00, 15, 15, 'Scheduled'),
(3, 2, '2026-12-05', '2026-12-12', NULL, 12, 12, 'Scheduled');

INSERT INTO tour_itinerary_stages (tour_id, day_number, location_id, room_type_id, stage_title, description) VALUES
(1, 1, 1, 1, 'Arrival and Carpathian Park Trail', 'Check-in at Edelweiss Resort and forest walk'),
(1, 2, 2, 1, 'Probiy Waterfall & Souvenir Market', 'Guided walk to the waterfall and local cheese tasting'),
(2, 1, 3, 2, 'Ancient Rome Evening Walk', 'Check-in and stroll through Historic Center'),
(2, 2, 4, 2, 'Colosseum & Roman Forum', 'Priority access tour inside the arena'),
(3, 1, 5, 3, 'Zermatt & Matterhorn Ascent', 'Cable car ride to Glacier Paradise');

INSERT INTO excursions (location_id, guide_user_id, title, duration_hours, price) VALUES
(2, 2, 'Hutsul Cheese & Wine Tasting', 3.0, 40.00),
(4, 3, 'Underground Colosseum Night Tour', 2.5, 75.00),
(5, 3, 'Glacier Ice Palace Walk', 4.0, 110.00);

INSERT INTO promotions (promo_code, discount_percent, valid_from, valid_to, max_uses, current_uses, is_active) VALUES
('AUTUMN10', 10.00, '2026-09-01', '2026-12-31', 100, 0, TRUE),
('VIP20', 20.00, '2026-01-01', '2026-12-31', 10, 0, TRUE);

-- === Етап 5: Демонстрація бізнес-сценаріїв (Бронювання, Платежі, Soft Delete, Аудит) ===

SET search_path TO tourism, public;

DO $$
DECLARE
    v_b_id BIGINT;
    v_b_num VARCHAR;
    v_total NUMERIC;
    v_pay_id BIGINT;
    v_status VARCHAR;
BEGIN
    CALL tourism.sp_create_booking(4, 4, 2, 2::smallint, 'AUTUMN10', 2, v_b_id, v_b_num, v_total);
    RAISE NOTICE 'Created Booking ID=%, Number=%, Total=%', v_b_id, v_b_num, v_total;

    CALL tourism.sp_register_payment(4, v_b_id, v_total, 'Card', 'TX-STRIPE-90001', v_pay_id, v_status);
    RAISE NOTICE 'Registered Payment ID=%, Updated Booking Status=%', v_pay_id, v_status;
END;
$$;

SELECT * FROM tourism.fn_search_tours('IT', DATE '2026-11-01', 1000.00, 'history');

SELECT booking_number, tourist_name, tour_title, total_amount, paid_amount, booking_status
FROM tourism.vw_booking_details;

CALL tourism.sp_soft_delete_tour(1, 3);

SELECT tour_id, tour_code, tour_title FROM tourism.vw_active_tour_offers;

SELECT * FROM tourism.vw_deleted_records_registry;

CALL tourism.sp_restore_soft_deleted_record(1, 'tours', 3);

SELECT log_id, table_name, record_id, operation_type, changed_by_user_id, changed_at
FROM tourism.audit_logs
ORDER BY log_id;

SELECT * FROM tourism.vw_agency_statistics;

-- === Етап 6: Аналіз роботи індексів ===

SET enable_seqscan = OFF;
EXPLAIN ANALYZE
SELECT tour_id, title, base_price
FROM tourism.tours
WHERE is_deleted = FALSE AND status = 'Active' AND agency_id = 2 AND base_price < 1500;

EXPLAIN ANALYZE
SELECT tour_id, title
FROM tourism.tours
WHERE tags @> ARRAY['mountains']::text[];
SET enable_seqscan = ON;
CREATE TABLE slots (
    id UUID PRIMARY KEY,
    title TEXT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE bookings (
    id UUID PRIMARY KEY,
    slot_id UUID NOT NULL UNIQUE REFERENCES slots(id),
    customer_name TEXT NOT NULL CHECK (char_length(customer_name) BETWEEN 2 AND 80),
    idempotency_key UUID NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO slots (id, title, starts_at)
VALUES (
    '11111111-1111-4111-8111-111111111111',
    'Architecture review',
    '2030-02-01T09:00:00Z'
);

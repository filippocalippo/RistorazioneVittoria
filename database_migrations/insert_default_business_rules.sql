-- Insert default business_rules configuration for single-tenant system
-- Run this in your Supabase SQL editor

INSERT INTO business_rules (
    id,
    attiva,
    chiusura_temporanea,
    nome_pizzeria,
    indirizzo,
    citta,
    cap,
    provincia,
    telefono,
    email,
    logo_url,
    immagine_copertina_url,
    orari,
    latitude,
    longitude,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    true,
    false,
    'La Mia Pizzeria',
    'Via Roma 123',
    'Roma',
    '00100',
    'RM',
    '+39 06 123456',
    'info@lamiapizzeria.it',
    null,
    null,
    '{
        "lunedi": {"aperto": false, "apertura": "18:00", "chiusura": "23:00"},
        "martedi": {"aperto": true, "apertura": "18:00", "chiusura": "23:00"},
        "mercoledi": {"aperto": true, "apertura": "18:00", "chiusura": "23:00"},
        "giovedi": {"aperto": true, "apertura": "18:00", "chiusura": "23:00"},
        "venerdi": {"aperto": true, "apertura": "18:00", "chiusura": "23:00"},
        "sabato": {"aperto": true, "apertura": "18:00", "chiusura": "23:00"},
        "domenica": {"aperto": true, "apertura": "18:00", "chiusura": "23:00"}
    }',
    41.9028,
    12.4964,
    now(),
    now()
) ON CONFLICT DO NOTHING;

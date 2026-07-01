-- 002_seed_data.sql
-- Datos de prueba para desarrollo

-- Admin: admin@moteros.com / admin123
-- Password hash: SHA256('admin123')
INSERT INTO users (email, password_hash, full_name, role)
VALUES ('admin@moteros.com', '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9', 'Admin Moteros', 'admin')
ON CONFLICT (email) DO NOTHING;

-- Lugar de prueba: Taller Moteros
INSERT INTO places (name, description, category, address, city, department, geom, qr_token, created_by)
VALUES (
    'Taller Moteros Garage',
    'Taller especializado en motos de alta cilindrada',
    'taller',
    'Calle 80 #15-20',
    'Bogota',
    'Cundinamarca',
    ST_SetSRID(ST_MakePoint(-74.08175, 4.60971), 4326),
    'QR-TALLER-MOTEROS-001',
    (SELECT id FROM users WHERE email = 'admin@moteros.com')
) ON CONFLICT (qr_token) DO NOTHING;

INSERT INTO places (name, description, category, address, city, department, geom, qr_token, created_by)
VALUES (
    'Moto-Posada El Viajero',
    'Alojamiento para moteros con parqueadero seguro',
    'moto_posada',
    'Km 12 Via La Calera',
    'La Calera',
    'Cundinamarca',
    ST_SetSRID(ST_MakePoint(-73.96932, 4.72076), 4326),
    'QR-POSADA-VIAJERO-002',
    (SELECT id FROM users WHERE email = 'admin@moteros.com')
) ON CONFLICT (qr_token) DO NOTHING;

INSERT INTO places (name, description, category, address, city, department, geom, qr_token, created_by)
VALUES (
    'Restaurante La Parrilla del Motero',
    'Comida tipica colombiana, parqueadero para motos',
    'restaurante',
    'Carrera 7 #72-50',
    'Bogota',
    'Cundinamarca',
    ST_SetSRID(ST_MakePoint(-74.05995, 4.65403), 4326),
    'QR-REST-PARRILLA-003',
    (SELECT id FROM users WHERE email = 'admin@moteros.com')
) ON CONFLICT (qr_token) DO NOTHING;

INSERT INTO places (name, description, category, address, city, department, geom, qr_token, created_by)
VALUES (
    'Mirador del Cerro',
    'Vista panoramica de Bogota, punto de encuentro motero',
    'mirador',
    'Cerro de Monserrate',
    'Bogota',
    'Cundinamarca',
    ST_SetSRID(ST_MakePoint(-74.05535, 4.60534), 4326),
    'QR-MIRADOR-CERRO-004',
    (SELECT id FROM users WHERE email = 'admin@moteros.com')
) ON CONFLICT (qr_token) DO NOTHING;

INSERT INTO places (name, description, category, address, city, department, geom, qr_token, created_by)
VALUES (
    'Gruas Motero Express',
    'Servicio de grua 24/7 para motos',
    'grua',
    'Av. Caracas #45-20',
    'Bogota',
    'Cundinamarca',
    ST_SetSRID(ST_MakePoint(-74.07309, 4.63230), 4326),
    'QR-GRUA-EXPRESS-005',
    (SELECT id FROM users WHERE email = 'admin@moteros.com')
) ON CONFLICT (qr_token) DO NOTHING;

-- Aliado de prueba
INSERT INTO allies (business_name, category, description, benefit, address, phone, website, latitude, longitude)
VALUES (
    'Moteros Garage',
    'taller',
    'Taller especializado en motos de alta cilindrada',
    '15% de descuento en mano de obra para miembros',
    'Calle 80 #15-20, Bogota',
    '6015551234',
    'https://moterosgarage.com',
    4.60971,
    -74.08175
);

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    github_id BIGINT UNIQUE NOT NULL,
    username VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'USER',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE greeting (
    id BIGSERIAL PRIMARY KEY,
    message VARCHAR(500) NOT NULL DEFAULT 'Hello, World!',
    updated_by BIGINT REFERENCES users (id),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

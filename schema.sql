-- ============================================================
-- DASC32003 Feedback Form — Supabase Schema v2
-- Run in Supabase SQL Editor to initialise or reset the database.
-- ============================================================

-- Drop in dependency order (safe: tables start empty)
DROP TABLE IF EXISTS peer_reviews CASCADE;
DROP TABLE IF EXISTS submissions  CASCADE;
DROP TABLE IF EXISTS students     CASCADE;
DROP TABLE IF EXISTS teams        CASCADE;

-- ── teams ──────────────────────────────────────────────────────────────
CREATE TABLE teams (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    team_number int4   NOT NULL UNIQUE
);

-- ── students ───────────────────────────────────────────────────────────
-- student_id : randomly assigned 1–1,000,000,000
--              Students enter this on the form; the app validates it here.
CREATE TABLE students (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id bigint NOT NULL UNIQUE
                   CHECK (student_id >= 1 AND student_id <= 1000000000),
    name       text   NOT NULL,
    team_id    bigint NOT NULL REFERENCES teams (id) ON DELETE CASCADE
);

-- ── submissions (presentation feedback) ───────────────────────────────
-- individual_feedback : jsonb  →  { "<student_id>": "feedback text", … }
CREATE TABLE submissions (
    id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at           timestamptz NOT NULL DEFAULT now(),
    submitter_student_id bigint      NOT NULL,
    reviewed_team_id     bigint      NOT NULL REFERENCES teams (id),
    q1  smallint NOT NULL CHECK (q1  BETWEEN 1 AND 5),
    q2  smallint NOT NULL CHECK (q2  BETWEEN 1 AND 5),
    q3  smallint NOT NULL CHECK (q3  BETWEEN 1 AND 5),
    q4  smallint NOT NULL CHECK (q4  BETWEEN 1 AND 5),
    q5  smallint NOT NULL CHECK (q5  BETWEEN 1 AND 5),
    q6  smallint NOT NULL CHECK (q6  BETWEEN 1 AND 5),
    q7  smallint NOT NULL CHECK (q7  BETWEEN 1 AND 5),
    q8  smallint NOT NULL CHECK (q8  BETWEEN 1 AND 5),
    q9  smallint NOT NULL CHECK (q9  BETWEEN 1 AND 5),
    q10 smallint NOT NULL CHECK (q10 BETWEEN 1 AND 5),
    individual_feedback jsonb NOT NULL DEFAULT '{}',
    CONSTRAINT uq_submission_student_team UNIQUE (submitter_student_id, reviewed_team_id)
);

-- ── peer_reviews ───────────────────────────────────────────────────────
-- One row per submitter→reviewee pair.  Scale: 1–3.
CREATE TABLE peer_reviews (
    id                   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at           timestamptz NOT NULL DEFAULT now(),
    submitter_student_id bigint      NOT NULL,
    reviewee_student_id  bigint      NOT NULL,
    q1  smallint NOT NULL CHECK (q1  BETWEEN 1 AND 3),
    q2  smallint NOT NULL CHECK (q2  BETWEEN 1 AND 3),
    q3  smallint NOT NULL CHECK (q3  BETWEEN 1 AND 3),
    q4  smallint NOT NULL CHECK (q4  BETWEEN 1 AND 3),
    q5  smallint NOT NULL CHECK (q5  BETWEEN 1 AND 3),
    q6  smallint NOT NULL CHECK (q6  BETWEEN 1 AND 3),
    feedback_text text NOT NULL DEFAULT '',
    CONSTRAINT uq_peer_review_pair UNIQUE (submitter_student_id, reviewee_student_id)
);

-- ── Row Level Security ─────────────────────────────────────────────────
--
--  Key         | teams | students | submissions | peer_reviews
--  ------------|-------|----------|-------------|-------------
--  anon        | READ  | READ     | INSERT only | INSERT only
--  service_role| full  | full     | full        | full (bypasses RLS)
--
ALTER TABLE teams        ENABLE ROW LEVEL SECURITY;
ALTER TABLE students     ENABLE ROW LEVEL SECURITY;
ALTER TABLE submissions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE peer_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_read_teams"
    ON teams FOR SELECT TO anon USING (true);

CREATE POLICY "anon_read_students"
    ON students FOR SELECT TO anon USING (true);

CREATE POLICY "anon_insert_submissions"
    ON submissions FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY "anon_insert_peer_reviews"
    ON peer_reviews FOR INSERT TO anon WITH CHECK (true);

-- ── Sample seed data (remove before production) ────────────────────────
-- INSERT INTO teams (team_number) VALUES (1),(2),(3);
--
-- INSERT INTO students (student_id, name, team_id) VALUES
--     (123456789, 'Alice Johnson', 1),
--     (234567890, 'Bob Smith',     1),
--     (345678901, 'Carol White',   2),
--     (456789012, 'Dave Brown',    2),
--     (567890123, 'Eve Davis',     3);

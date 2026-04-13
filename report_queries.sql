-- ============================================================
-- report_queries.sql  —  Ad-hoc SQL for the Supabase SQL Editor
-- Run these as the professor (service role) to inspect data directly.
-- Replace placeholder values (marked ←) with real student/team IDs.
-- ============================================================

-- ── 1. All presentation feedback received by a specific student ─────────
-- Returns one row per submission, with that student's individual feedback.

SELECT
    sub.created_at,
    t.team_number                           AS reviewer_team,
    (sub.scores->>'q1')::int                AS q1,
    (sub.scores->>'q2')::int                AS q2,
    (sub.scores->>'q3')::int                AS q3,
    (sub.scores->>'q4')::int                AS q4,
    (sub.scores->>'q5')::int                AS q5,
    (sub.scores->>'q6')::int                AS q6,
    (sub.scores->>'q7')::int                AS q7,
    (sub.scores->>'q8')::int                AS q8,
    (sub.scores->>'q9')::int                AS q9,
    (sub.scores->>'q10')::int               AS q10,
    sub.individual_feedback->>st.student_id::text AS student_feedback
FROM submissions sub
JOIN teams    t  ON t.id       = sub.reviewed_team_id
JOIN students st ON st.team_id = t.id
WHERE st.student_id = 123456789             -- ← target student's random ID
ORDER BY sub.created_at DESC;


-- ── 2. Team average scores across all presentation feedback ─────────────

SELECT
    t.team_number,
    COUNT(sub.id)                                   AS review_count,
    ROUND(AVG(sub.q1)::numeric,  2)                 AS avg_q1,
    ROUND(AVG(sub.q2)::numeric,  2)                 AS avg_q2,
    ROUND(AVG(sub.q3)::numeric,  2)                 AS avg_q3,
    ROUND(AVG(sub.q4)::numeric,  2)                 AS avg_q4,
    ROUND(AVG(sub.q5)::numeric,  2)                 AS avg_q5,
    ROUND(AVG(sub.q6)::numeric,  2)                 AS avg_q6,
    ROUND(AVG(sub.q7)::numeric,  2)                 AS avg_q7,
    ROUND(AVG(sub.q8)::numeric,  2)                 AS avg_q8,
    ROUND(AVG(sub.q9)::numeric,  2)                 AS avg_q9,
    ROUND(AVG(sub.q10)::numeric, 2)                 AS avg_q10,
    ROUND(
        (AVG(sub.q1)+AVG(sub.q2)+AVG(sub.q3)+AVG(sub.q4)+AVG(sub.q5)+
         AVG(sub.q6)+AVG(sub.q7)+AVG(sub.q8)+AVG(sub.q9)+AVG(sub.q10)
        )::numeric / 10.0
    , 2)                                             AS overall_avg
FROM submissions sub
JOIN teams t ON t.id = sub.reviewed_team_id
GROUP BY t.id, t.team_number
ORDER BY t.team_number;


-- ── 3. All individual text feedback for a specific student (text only) ──

SELECT
    sub.created_at,
    sub.individual_feedback->>st.student_id::text AS feedback
FROM submissions sub
JOIN teams    t  ON t.id       = sub.reviewed_team_id
JOIN students st ON st.team_id = t.id
WHERE st.student_id = 123456789             -- ← target student's random ID
  AND (sub.individual_feedback->>st.student_id::text) IS NOT NULL
  AND LENGTH(TRIM(sub.individual_feedback->>st.student_id::text)) > 0
ORDER BY sub.created_at DESC;


-- ── 4. All peer reviews received by a specific student ──────────────────

SELECT
    pr.created_at,
    pr.q1, pr.q2, pr.q3, pr.q4, pr.q5, pr.q6,
    ROUND((pr.q1+pr.q2+pr.q3+pr.q4+pr.q5+pr.q6)::numeric/6.0, 2) AS avg_score,
    pr.feedback_text
FROM peer_reviews pr
WHERE pr.reviewee_student_id = 123456789    -- ← target student's random ID
ORDER BY pr.created_at DESC;


-- ── 5. How many reviews each student has received ───────────────────────

SELECT
    st.name,
    st.student_id,
    t.team_number,
    COUNT(DISTINCT sub.id)  AS presentation_reviews,
    COUNT(DISTINCT pr.id)   AS peer_reviews_received
FROM students st
JOIN teams t ON t.id = st.team_id
LEFT JOIN submissions  sub ON sub.reviewed_team_id    = t.id
LEFT JOIN peer_reviews pr  ON pr.reviewee_student_id  = st.student_id
GROUP BY st.id, st.name, st.student_id, t.team_number
ORDER BY t.team_number, st.name;


-- ── 6. Full submission dump ──────────────────────────────────────────────

SELECT
    sub.id,
    sub.created_at,
    sub.submitter_student_id,
    t.team_number              AS reviewed_team,
    sub.q1, sub.q2, sub.q3, sub.q4, sub.q5,
    sub.q6, sub.q7, sub.q8, sub.q9, sub.q10,
    sub.individual_feedback
FROM submissions sub
JOIN teams t ON t.id = sub.reviewed_team_id
ORDER BY sub.created_at DESC;

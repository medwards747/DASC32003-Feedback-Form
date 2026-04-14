"""
supabase_manager.py
-------------------
All Supabase interactions for the DASC32003 Feedback System.

Two clients are used by the app:
  • anon key   → tabs 1 & 2 (students): SELECT on teams/students, INSERT on submissions/peer_reviews
  • service key → tab 3 (professor): full read access, bypasses RLS
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from supabase import Client, create_client


# ── Data-transfer objects ──────────────────────────────────────────────────

@dataclass
class Team:
    id: int
    team_number: int


@dataclass
class Student:
    id: int           # internal DB primary key
    student_id: int   # randomly assigned 1–1,000,000,000 (what students enter)
    name: str
    team_id: int


@dataclass
class Submission:
    id: str
    created_at: str
    submitter_student_id: int
    reviewed_team_id: int
    scores: dict[str, int]         # {"q1": 3, …, "q10": 5}
    individual_feedback: dict[str, str]  # {str(student_id): feedback_text}


@dataclass
class PeerReview:
    id: str
    created_at: str
    submitter_student_id: int
    reviewee_student_id: int
    scores: dict[str, int]         # {"q1": 2, …, "q6": 3}
    feedback_text: str


@dataclass
class SubmissionPayload:
    submitter_student_id: int
    reviewed_team_id: int
    scores: dict[str, int]
    individual_feedback: dict[str, str]


@dataclass
class PeerReviewPayload:
    submitter_student_id: int
    reviewee_student_id: int
    scores: dict[str, int]
    feedback_text: str


# ── Manager ────────────────────────────────────────────────────────────────

class SupabaseManager:
    def __init__(self, url: str, key: str) -> None:
        self._client: Client = create_client(url, key)

    # ── internal helpers ────────────────────────────────────────────────

    @staticmethod
    def _row_to_student(row: dict) -> Student:
        return Student(
            id=row["id"],
            student_id=row["student_id"],
            name=row["name"],
            team_id=row["team_id"],
        )

    @staticmethod
    def _row_to_submission(row: dict) -> Submission:
        return Submission(
            id=row["id"],
            created_at=row["created_at"],
            submitter_student_id=row["submitter_student_id"],
            reviewed_team_id=row["reviewed_team_id"],
            scores={f"q{i}": row[f"q{i}"] for i in range(1, 11)},
            individual_feedback=row.get("individual_feedback") or {},
        )

    @staticmethod
    def _row_to_peer_review(row: dict) -> PeerReview:
        return PeerReview(
            id=row["id"],
            created_at=row["created_at"],
            submitter_student_id=row["submitter_student_id"],
            reviewee_student_id=row["reviewee_student_id"],
            scores={f"q{i}": row[f"q{i}"] for i in range(1, 7)},
            feedback_text=row.get("feedback_text") or "",
        )

    # ── teams ────────────────────────────────────────────────────────────

    def get_teams(self) -> list[Team]:
        try:
            r = (
                self._client.table("teams")
                .select("id, team_number")
                .order("team_number")
                .execute()
            )
            return [Team(id=row["id"], team_number=row["team_number"]) for row in r.data]
        except Exception as e:
            raise RuntimeError(f"Failed to fetch teams: {e}") from e

    # ── students ─────────────────────────────────────────────────────────

    def get_student_by_random_id(self, student_id: int) -> Student | None:
        try:
            r = (
                self._client.table("students")
                .select("*")
                .eq("student_id", student_id)
                .limit(1)
                .execute()
            )
            return self._row_to_student(r.data[0]) if r.data else None
        except Exception as e:
            raise RuntimeError(f"Failed to look up student: {e}") from e

    def get_students_by_team(self, team_id: int) -> list[Student]:
        try:
            r = (
                self._client.table("students")
                .select("*")
                .eq("team_id", team_id)
                .order("name")
                .execute()
            )
            return [self._row_to_student(row) for row in r.data]
        except Exception as e:
            raise RuntimeError(f"Failed to fetch students for team {team_id}: {e}") from e

    def get_all_students(self) -> list[Student]:
        try:
            r = (
                self._client.table("students")
                .select("*")
                .order("team_id")
                .order("name")
                .execute()
            )
            return [self._row_to_student(row) for row in r.data]
        except Exception as e:
            raise RuntimeError(f"Failed to fetch all students: {e}") from e

    # ── submissions ──────────────────────────────────────────────────────

    def insert_submission(self, payload: SubmissionPayload) -> dict[str, Any]:
        try:
            row: dict[str, Any] = {
                "submitter_student_id": payload.submitter_student_id,
                "reviewed_team_id": payload.reviewed_team_id,
                "individual_feedback": payload.individual_feedback,
                **{f"q{i}": payload.scores[f"q{i}"] for i in range(1, 11)},
            }
            # returning="minimal" prevents PostgREST from SELECT-ing the row back
            # after insert, which would be blocked by RLS (no SELECT policy on submissions).
            self._client.table("submissions").insert(row, returning="minimal").execute()
            return {}
        except Exception as e:
            raise RuntimeError(f"Failed to insert submission: {e}") from e

    def get_submissions_for_team(self, team_id: int) -> list[Submission]:
        try:
            r = (
                self._client.table("submissions")
                .select("*")
                .eq("reviewed_team_id", team_id)
                .order("created_at")
                .execute()
            )
            return [self._row_to_submission(row) for row in r.data]
        except Exception as e:
            raise RuntimeError(f"Failed to fetch submissions for team {team_id}: {e}") from e

    def get_all_submissions(self) -> list[Submission]:
        try:
            r = (
                self._client.table("submissions")
                .select("*")
                .order("created_at")
                .execute()
            )
            return [self._row_to_submission(row) for row in r.data]
        except Exception as e:
            raise RuntimeError(f"Failed to fetch all submissions: {e}") from e

    # ── peer reviews ─────────────────────────────────────────────────────

    def insert_peer_review(self, payload: PeerReviewPayload) -> dict[str, Any]:
        try:
            row: dict[str, Any] = {
                "submitter_student_id": payload.submitter_student_id,
                "reviewee_student_id": payload.reviewee_student_id,
                "feedback_text": payload.feedback_text,
                **{f"q{i}": payload.scores[f"q{i}"] for i in range(1, 7)},
            }
            # returning="minimal" avoids the post-insert SELECT that RLS would block.
            self._client.table("peer_reviews").insert(row, returning="minimal").execute()
            return {}
        except Exception as e:
            raise RuntimeError(f"Failed to insert peer review: {e}") from e

    def get_all_peer_reviews(self) -> list[PeerReview]:
        try:
            r = (
                self._client.table("peer_reviews")
                .select("*")
                .order("created_at")
                .execute()
            )
            return [self._row_to_peer_review(row) for row in r.data]
        except Exception as e:
            raise RuntimeError(f"Failed to fetch peer reviews: {e}") from e

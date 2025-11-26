"""
generator.py

Generate synthetic user- and event-level data for a digital health app
supporting chronic disease patients (e.g., diabetes/hypertension).

Outputs:
    - users.csv   : one row per user
    - events.csv  : one row per event

Run:
    python generator.py
"""

import random
import uuid
from datetime import timedelta
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker


# Global config & RNG seeding
N_USERS = 50_000

fake = Faker()
Faker.seed(42)
np.random.seed(42)
random.seed(42)

DATA_DIR = Path(__file__).resolve().parent


# Helper functions
def sample_location_type() -> str:
    return np.random.choice(["urban", "rural"], p=[0.65, 0.35])


def sample_device_type_and_os() -> tuple[str, str]:
    device_type = np.random.choice(["iOS", "Android", "Web"], p=[0.4, 0.5, 0.1])

    if device_type == "iOS":
        ios_versions = ["iOS 15.7", "iOS 16.6", "iOS 17.0", "iOS 17.5"]
        version = np.random.choice(ios_versions)
    elif device_type == "Android":
        android_versions = [
            "Android 11",
            "Android 12",
            "Android 13",
            "Android 14",
        ]
        version = np.random.choice(android_versions)
    else:
        web_versions = [
            "Chrome 120",
            "Chrome 121",
            "Firefox 120",
            "Edge 120",
        ]
        version = np.random.choice(web_versions)

    return device_type, version


def sample_treatment_plan(baseline_severity: int) -> str:
    if baseline_severity <= 2:
        return np.random.choice(["lifestyle_only", "oral_medication"], p=[0.5, 0.5])
    elif baseline_severity == 3:
        return np.random.choice(["oral_medication", "combo"], p=[0.6, 0.4])
    else:
        return np.random.choice(["combo", "insulin"], p=[0.5, 0.5])


def sample_adherence_flag(baseline_severity: int, location_type: str) -> int:
    base_prob = 0.75

    severity_penalty = 0.03 * (baseline_severity - 3)
    rural_penalty = 0.05 if location_type == "rural" else 0.0

    prob_adherent = base_prob - severity_penalty - rural_penalty
    prob_adherent = np.clip(prob_adherent, 0.2, 0.95)

    return int(np.random.rand() < prob_adherent)


# Core generation functions
def generate_users(n_users: int) -> pd.DataFrame:
    rows = []

    for _ in range(n_users):
        user_id = str(uuid.uuid4())
        signup_date = fake.date_between(start_date="-1y", end_date="today")
        age = np.random.randint(18, 81)  # 18-80
        gender = np.random.choice(["Male", "Female", "Other"], p=[0.48, 0.48, 0.04])
        location = fake.city()
        location_type = sample_location_type()
        device_type, device_os_version = sample_device_type_and_os()
        baseline_severity = np.random.choice(
            [1, 2, 3, 4, 5], p=[0.15, 0.25, 0.3, 0.2, 0.1]
        )
        treatment_plan = sample_treatment_plan(baseline_severity)
        adherence_flag = sample_adherence_flag(baseline_severity, location_type)

        rows.append(
            {
                "user_id": user_id,
                "signup_date": signup_date,
                "age": age,
                "gender": gender,
                "location": location,
                "location_type": location_type,
                "device_type": device_type,
                "device_os_version": device_os_version,
                "baseline_severity": baseline_severity,
                "treatment_plan": treatment_plan,
                "adherence_flag": adherence_flag,
            }
        )

    users_df = pd.DataFrame(rows)
    return users_df


def generate_events(users_df: pd.DataFrame) -> pd.DataFrame:
    events = []
    event_types = ["login", "view_tutorial", "connect_device", "submit_reading"]

    for _, row in users_df.iterrows():
        user_id = row["user_id"]
        signup = pd.to_datetime(row["signup_date"])

        base_engage_prob = 0.7
        severity_penalty = 0.05 * (row["baseline_severity"] - 3)
        adherence_bonus = 0.1 if row["adherence_flag"] == 1 else -0.05

        engage_prob = base_engage_prob - severity_penalty + adherence_bonus
        engage_prob = float(np.clip(engage_prob, 0.1, 0.95))

        engages = np.random.rand() < engage_prob

        n_events = np.random.poisson(lam=3) + 1
        current_time = signup

        for _ in range(n_events):
            delta_days = np.random.randint(1, 8)
            current_time = current_time + timedelta(days=delta_days)

            if (current_time - signup).days > 30:
                break

            ev_type = np.random.choice(event_types, p=[0.4, 0.2, 0.2, 0.2])
            events.append(
                {
                    "user_id": user_id,
                    "event_type": ev_type,
                    "timestamp": current_time,
                    "device_type": row["device_type"],
                    "device_os_version": row["device_os_version"],
                }
            )

        if engages:
            delta_days = np.random.randint(1, 31)
            contact_time = signup + timedelta(days=delta_days)
            events.append(
                {
                    "user_id": user_id,
                    "event_type": "care_team_contact",
                    "timestamp": contact_time,
                    "device_type": row["device_type"],
                    "device_os_version": row["device_os_version"],
                }
            )

    events_df = pd.DataFrame(events)
    return events_df


def derive_outcomes(users_df: pd.DataFrame, events_df: pd.DataFrame) -> pd.DataFrame:
    care_events = events_df[events_df["event_type"] == "care_team_contact"].copy()

    if care_events.empty:
        users_df["first_contact_time"] = pd.NaT
        users_df["dropoff"] = 1
        return users_df

    contact_times = care_events.groupby("user_id")["timestamp"].min().reset_index()
    contact_times.rename(columns={"timestamp": "first_contact_time"}, inplace=True)

    users_df = users_df.merge(contact_times, on="user_id", how="left")

    signup_dt = pd.to_datetime(users_df["signup_date"])
    contact_dt = pd.to_datetime(users_df["first_contact_time"])

    delta_days = (contact_dt - signup_dt).dt.days
    users_df["dropoff"] = (
        users_df["first_contact_time"].isna() | (delta_days > 30)
    ).astype(int)

    return users_df


def main() -> None:
    print(f"Generating {N_USERS} users...")
    users_df = generate_users(N_USERS)

    print("Generating events...")
    events_df = generate_events(users_df)

    print("Deriving outcomes (first_contact_time, dropoff)...")
    users_with_outcomes_df = derive_outcomes(users_df, events_df)

    users_path = DATA_DIR / "users.csv"
    events_path = DATA_DIR / "events.csv"

    print(f"Writing users to {users_path}")
    users_with_outcomes_df.to_csv(users_path, index=False)

    print(f"Writing events to {events_path}")
    events_df.to_csv(events_path, index=False)

    dropoff_rate = users_with_outcomes_df["dropoff"].mean()
    print(
        f"Done. Users: {len(users_with_outcomes_df)}, "
        f"Events: {len(events_df)}, "
        f"Drop-off rate: {dropoff_rate:.2%}"
    )


if __name__ == "__main__":
    main()

# Data model

SwiftData entities. All models local-only; no CloudKit in MVP. Volume = Σ(reps × weight) per
exercise/muscle group/workout.

## Entities

### `Exercise` (seeded library, user-extendable later)
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `name` | `String` | e.g. "Bench Press" |
| `muscleGroup` | `String` | enum raw: chest, back, legs, shoulders, arms, core, cardio |
| `isCardio` | `Bool` | cardio logs duration/distance instead of sets |

### `Workout`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `title` | `String` | user-editable, default "Chest Day" style from exercises |
| `startedAt` | `Date` | session start |
| `endedAt` | `Date?` | nil while session is live; set on finish |
| `feelRating` | `Int?` | 1–5 (awful → great), nil = not set |
| `painLevel` | `Int?` | 0 none, 1 mild, 2 moderate, 3 severe |
| `painLocation` | `String` | free text, only meaningful when painLevel ≥ 1 |
| `notes` | `String` | free-form |
| `musicProvider` | `String?` | `spotify`, `appleMusic`, nil |
| `musicPlaylistID` / `musicPlaylistName` | `String?` | provider-side identifiers |
| `sets` | `[SetEntry]` | cascade delete with workout |

### `SetEntry`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `workout` | `Workout` | inverse of `sets` |
| `exercise` | `Exercise` | |
| `index` | `Int` | ordering within (workout, exercise) |
| `reps` | `Int` | |
| `weightKg` | `Double` | kg internally; display converts to user unit |
| `rpe` | `Double?` | optional rate of perceived exertion 1–10 |

Cardio sets: `reps` = duration minutes, `weightKg` = 0, distance stored in `rpe`? **No** —
add `distanceKm: Double?` to `SetEntry`. (Decision recorded here so it isn't improvised later.)

### `Goal`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `kind` | `String` | `weeklyWorkouts`, `bodyWeight`, `oneRepMax` |
| `targetValue` | `Double` | count / kg / kg |
| `exercise` | `Exercise?` | only for `oneRepMax` |
| `createdAt` | `Date` | |

Derived progress: weeklyWorkouts = count this week; bodyWeight = latest HealthKit mass;
oneRepMax = max Epley estimate for that exercise.

## Derived (never stored)

- **BMI** = mass kg / (height m)², from HealthKit height + latest mass. Category bands use
  WHO standard (<18.5, <25, <30, ≥30).
- **Estimated 1RM** (Epley) = weight × (1 + reps/30).
- **Volume** = Σ(reps × weightKg) over the requested grouping.

## HealthKit mapping

| HealthKit type | Direction | Used for |
|---|---|---|
| `.heartRate` | read | per-workout avg/peak HR (AirPods Pro 3 + Watch sources) |
| `.restingHeartRate` | read | Progress trend |
| `.heartRateVariabilitySDNN` | read | Progress trend |
| `.activeEnergyBurned` | read/write | workout summary; written on finish |
| `.bodyMass` | read | weight trend + BMI |
| `.height` | read | BMI |
| `.workoutType` (HKWorkout) | read/write | Apple Fitness workouts list; save on finish |
| `.appleExerciseTime` | read | weekly workouts goal fallback |

## Seed data

First launch seeds ~30 common exercises across the seven muscle groups, idempotently (check
name collision before insert).

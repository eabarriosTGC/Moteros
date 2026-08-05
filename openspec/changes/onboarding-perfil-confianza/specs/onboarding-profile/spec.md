# Delta for onboarding-profile

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| OP-R1 | First-access gate SHALL validate real field presence: `full_name`, `bike_model`, and `city` MUST all be non-empty before navigation is allowed. The `onboarding_complete` boolean metadata flag SHALL NOT satisfy the gate. | MUST |
| OP-R2 | The system MUST NOT collect cédula numbers or identity documents at any point. Recorded decision under Ley 1581 de 2012 (data responsibility) — deliberate, not an omission. | MUST NOT |
| OP-R3 | The three profile fields SHALL be editable after onboarding from Progreso → Perfil (ProfileScreen); edits SHALL persist to the `users` row. | MUST |
| OP-R4 | OnboardingScreen SHALL require only `full_name`, `bike_model`, `city`. `phone` and emergency contact SHALL be optional. | MUST |

> Note (Safe Mode): `phone`/emergency were previously required and may still be stored; a future Safe Mode reactivation MUST re-collect them explicitly.

```
Given: user metadata has onboarding_complete=true but users.full_name / bike_model / city are empty
When: app starts
Then: onboarding form is shown — the boolean flag does NOT satisfy the gate
And: the phantom-flag case (flag set, data absent) is treated as incomplete

Given: a user with full_name, bike_model, city all non-empty
When: app starts
Then: navigation proceeds past onboarding

Given: a user missing city only (full_name and bike_model present)
When: app starts
Then: onboarding form is shown with a validation error on city
```

```
Given: onboarding or profile forms are rendered
When: any field is inspected
Then: no cédula/ID field exists and no identity document is requested or stored
```

```
Given: an onboarded user opens Progreso → Perfil
When: they edit bike_model and save
Then: users.bike_model updates
And: the next app start shows the updated value

Given: an onboarded user opens Progreso → Perfil
When: they change city and phone, leaving emergency empty
Then: city persists; emergency remains empty without validation error
```

```
Given: a new user on OnboardingScreen
When: submitting with full_name, bike_model, city and empty phone/emergency
Then: submission succeeds — optional fields are skipped

Given: a new user on OnboardingScreen
When: submitting without bike_model
Then: validation blocks submission — bike_model stays required
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Widget tests: gate blocks the phantom-flag case (OP-R1) and allows real-data users; onboarding validation distinguishes required vs optional fields (OP-R4); profile edit persists (OP-R3).

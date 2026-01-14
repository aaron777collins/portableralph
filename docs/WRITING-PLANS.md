# Writing Effective Plans

How to write plan files that Ralph can execute successfully.

## Overview

A plan file is a markdown document that describes what you want Ralph to build. The better your plan, the better Ralph's output.

## Basic Structure

```markdown
# [Type]: [Short Title]

## Goal
What you want to achieve in 1-2 sentences.

## Requirements
- Specific, actionable items
- Measurable acceptance criteria
- Clear scope boundaries

## Context (optional)
- Relevant files or patterns
- Constraints or preferences
- Technical decisions already made
```

## Plan Types

### Bug Fix

```markdown
# Fix: Login Button Not Responding

## Problem
The login button on /login page doesn't submit the form when clicked.

## Expected Behavior
Clicking login should POST to /api/auth/login and redirect to /dashboard on success.

## Reproduction Steps
1. Go to /login
2. Enter valid credentials
3. Click "Login" button
4. Nothing happens (no network request)

## Relevant Files
- src/pages/login.tsx
- src/components/LoginForm.tsx
```

### New Feature

```markdown
# Feature: User Profile Avatars

## Goal
Allow users to upload and display profile avatars.

## Requirements
- Upload endpoint accepting JPEG/PNG up to 5MB
- Resize images to 200x200 on upload
- Store in /uploads/avatars/{user_id}.jpg
- Display avatar in header and profile page
- Fallback to initials if no avatar

## Acceptance Criteria
- POST /api/users/avatar accepts image upload
- GET /api/users/{id}/avatar returns image or 404
- Profile page shows avatar or initials fallback
- Header shows small avatar thumbnail

## Technical Notes
- Use sharp for image resizing
- Follow existing upload pattern in src/lib/uploads.ts
```

### Refactoring

```markdown
# Refactor: Extract API Client

## Goal
Consolidate scattered fetch calls into a centralized API client.

## Current State
- fetch() calls duplicated across 15+ components
- No consistent error handling
- Auth headers added manually each time

## Target State
- Single ApiClient class in src/lib/api.ts
- Automatic auth header injection
- Consistent error handling with typed errors
- All components use ApiClient instead of raw fetch

## Constraints
- Don't change API response shapes
- Maintain existing error messages for users
- Keep all existing tests passing

## Files to Update
- src/components/*.tsx (all files with fetch calls)
- src/lib/api.ts (create new)
- src/types/api.ts (add error types)
```

### Migration/Upgrade

```markdown
# Migrate: React Router v5 to v6

## Goal
Upgrade from React Router v5 to v6 for improved performance and hooks API.

## Scope
- Update react-router-dom to v6
- Migrate all route definitions
- Update all useHistory to useNavigate
- Update all <Switch> to <Routes>
- Update all <Route> component patterns

## Out of Scope
- Adding new routes
- Changing URL structure
- Authentication flow changes

## Testing
- All existing routes must work identically
- Deep links must resolve correctly
- Back/forward navigation must work
```

## Best Practices

### Be Specific

```markdown
# Bad: vague
## Requirements
- Make the app faster
- Improve the UI
- Fix bugs

# Good: specific
## Requirements
- Reduce initial load time to under 2 seconds
- Add loading skeletons to dashboard cards
- Fix: clicking "Save" twice creates duplicate entries
```

### Define Acceptance Criteria

```markdown
## Acceptance Criteria
- User can upload avatar via drag-and-drop or file picker
- Uploads over 5MB show error message
- Invalid file types show "Please upload a JPEG or PNG"
- Avatar appears immediately after upload (no refresh needed)
```

### Include Context

```markdown
## Technical Context
- We use Prisma for database access (see prisma/schema.prisma)
- Auth is handled by NextAuth (see src/pages/api/auth/[...nextauth].ts)
- Follow the existing pattern in src/lib/users.ts for user operations
```

### Set Boundaries

```markdown
## In Scope
- User avatar upload
- Avatar display in header
- Avatar display on profile

## Out of Scope
- Avatar cropping UI
- Multiple avatar sizes
- Avatar deletion
```

## Tips for Complex Plans

### Break Into Phases

For large features, create multiple plan files:

```
plans/
├── auth-phase1-basic-login.md
├── auth-phase2-password-reset.md
├── auth-phase3-oauth.md
└── auth-phase4-mfa.md
```

### Reference Existing Patterns

```markdown
## Technical Notes
- Follow the validation pattern in src/lib/validators/user.ts
- Use the existing Modal component from src/components/Modal.tsx
- Error handling should match src/lib/errors.ts patterns
```

### Provide Examples

```markdown
## API Design

### Request
POST /api/avatars
Content-Type: multipart/form-data

file: <binary>

### Response (success)
{
  "url": "/uploads/avatars/123.jpg",
  "size": 45678
}

### Response (error)
{
  "error": "File too large",
  "maxSize": 5242880
}
```

## Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Too vague | Ralph guesses wrong | Add specific requirements |
| Too large | Takes forever, goes off track | Break into smaller plans |
| No context | Ralph reinvents patterns | Reference existing code |
| No criteria | Can't verify completion | Add acceptance criteria |
| Assumes state | Ralph can't find things | Describe current state |

## Template

Copy this template to start a new plan:

```markdown
# [Fix/Feature/Refactor]: [Title]

## Goal
[One sentence describing the objective]

## Current State
[What exists now, if relevant]

## Requirements
- [ ] Requirement 1
- [ ] Requirement 2
- [ ] Requirement 3

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Technical Notes
- [Relevant files, patterns, or constraints]

## Out of Scope
- [What this plan does NOT include]
```

---

Next: [How It Works](./HOW-IT-WORKS.md) | [Usage Guide](./USAGE.md)

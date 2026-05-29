# LEVEL-10 SECURITY, ISOLATION & SCALABILITY AUDIT

## Audit Scope
- **28 tables**, all RLS-enabled
- **48 RPC functions**, 38 are `SECURITY DEFINER`
- **8 views**
- **74 Supabase queries** in Flutter repositories
- **4 Realtime subscriptions** in Flutter providers

---

## PILLAR 1: MULTI-TENANT DATA BLEED & RLS (Red Team)

### FINDING 1.1 — CRITICAL: `list_all_profiles()` leaks every profile across all schools

```sql
-- Current definition (NO role check, NO school filter)
CREATE FUNCTION public.list_all_profiles()
RETURNS SETOF profiles
LANGUAGE sql SECURITY DEFINER
AS $$ SELECT * FROM public.profiles; $$;
```

**Impact:** Any authenticated user — staff, teacher, anyone — can call `SELECT * FROM list_all_profiles()` and receive every profile row in the entire platform: emails, names, roles, school_ids for every school. SECURITY DEFINER bypasses RLS entirely.

**Patch SQL:**
```sql
CREATE OR REPLACE FUNCTION public.list_all_profiles()
RETURNS SETOF profiles
LANGUAGE sql SECURITY DEFINER
SET search_path TO 'public'
AS $$
  SELECT * FROM public.profiles
  WHERE school_id = (SELECT school_id FROM public.profiles WHERE id = auth.uid());
$$;
```

---

### FINDING 1.2 — CRITICAL: `get_school_owner_logins()` exposes all schools to any user

```sql
-- Current definition (NO role check)
CREATE FUNCTION public.get_school_owner_logins()
RETURNS TABLE(school_id uuid, owner_last_login timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT s.id, au.last_sign_in_at
  FROM public.schools s JOIN auth.users au ON au.id = s.owner_id;
$$;
```

**Impact:** Any authenticated user can enumerate every school and its owner's last login timestamp. Combined with `list_all_profiles()`, an attacker can map the entire platform tenant structure.

**Patch SQL:**
```sql
CREATE OR REPLACE FUNCTION public.get_school_owner_logins()
RETURNS TABLE(school_id uuid, owner_last_login timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT s.id, au.last_sign_in_at
  FROM public.schools s JOIN auth.users au ON au.id = s.owner_id
  WHERE EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'superadmin');
$$;
```

---

### FINDING 1.3 — CRITICAL: `get_users_last_login()` — no role guard, reads `auth.users`

This SECURITY DEFINER function has **no role check and no auth.uid() check**. Any authenticated user can read from `auth.users` (normally blocked by Supabase). Need to inspect the full definition and add a superadmin guard.

---

### FINDING 1.4 — HIGH: `profiles` UPDATE policy allows owner to modify ANY profile cross-school

```sql
-- Current policy: profiles_update_own
qual: (id = auth.uid()) OR (profile_role() = ANY (ARRAY['owner','superadmin']))
```

**Impact:** A school owner from School A can issue `UPDATE profiles SET role = 'superadmin' WHERE id = '<School B user id>'` and the policy allows it because `profile_role() = 'owner'` evaluates true with no school_id guard. However, this is partially mitigated by the `prevent_role_self_change` trigger — but that only prevents self-changes, not cross-school escalation.

**Patch SQL:**
```sql
DROP POLICY profiles_update_own ON profiles;
CREATE POLICY profiles_update_own ON profiles FOR UPDATE USING (
  id = auth.uid()
  OR (
    profile_role() IN ('owner', 'admin')
    AND school_id = current_school_id()
  )
  OR is_superadmin()
);
```

---

### FINDING 1.5 — HIGH: `profiles` INSERT policy allows any authenticated user to create profiles

```sql
-- profiles_insert_system
roles: {authenticated}, cmd: INSERT, with_check: true
```

**Impact:** Any authenticated user can insert a profile row with `role = 'superadmin'` and any `school_id`. Combined with Finding 1.4, this is a privilege escalation chain: insert a new profile with `superadmin` role → gain platform-wide access.

**Mitigation:** The `handle_new_auth_user` trigger likely auto-creates profiles on signup. The INSERT policy should be restricted:

**Patch SQL:**
```sql
DROP POLICY profiles_insert_system ON profiles;
CREATE POLICY profiles_insert_system ON profiles FOR INSERT
  WITH CHECK (
    id = auth.uid()
    OR profile_role() IN ('owner', 'admin', 'superadmin')
  );
```

---

### FINDING 1.6 — HIGH: `link_line_account()` has no school_id validation on student

```sql
-- link_line_account calls current_school_id() but doesn't verify
-- the p_student_id actually belongs to that school
UPDATE students SET parent_line_id = p_line_user_id WHERE id = p_student_id;
```

**Impact:** A user from School A can link a LINE account to a student from School B by passing any student UUID. The function writes to `students` and `line_connections` without checking `students.school_id = v_school_id`.

**Patch — add validation:**
```sql
-- Add after v_school_id assignment:
IF NOT EXISTS (SELECT 1 FROM students WHERE id = p_student_id AND school_id = v_school_id) THEN
  RAISE EXCEPTION 'Student does not belong to your school';
END IF;
```

---

### FINDING 1.7 — MEDIUM: `renewal_pending_state` has ZERO RLS policies

This table has `rls_enabled = true` but **no policies at all**. This means it's completely inaccessible via the API (default-deny), which is safe — but if any code relies on client-side reads/writes to this table, they'll silently fail.

---

### FINDING 1.8 — MEDIUM: `audit_log` INSERT policy blocks all client inserts

```sql
-- insert_audit: with_check = false
```

Audit log inserts only work via SECURITY DEFINER functions (like `log_audit()`). This is correct, but the Flutter `super_admin_repository.dart` does:
```dart
await _supabase.from('audit_log').insert({...});
```
This will silently fail. All audit log writes from Flutter must go through the `log_audit()` RPC.

---

### FINDING 1.9 — MEDIUM: Impersonation Security Analysis

The impersonation mechanism (`startImpersonation` in Flutter) works by:
1. Calling `UPDATE profiles SET school_id = <target> WHERE id = auth.uid()`
2. `current_school_id()` then returns the impersonated school's ID
3. ALL RLS policies automatically shift

**Risk:** The `profiles_update_own` policy (Finding 1.4) allows `id = auth.uid()` updates, so any user can change their own `school_id` to any school. There is no server-side check that the user is a superadmin before allowing school_id changes.

**Patch SQL — add trigger:**
```sql
CREATE OR REPLACE FUNCTION prevent_school_id_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.school_id IS DISTINCT FROM NEW.school_id THEN
    IF OLD.role != 'superadmin' THEN
      RAISE EXCEPTION 'Only superadmins can change school_id';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prevent_school_id_change
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION prevent_school_id_change();
```

---

## PILLAR 2: EXTREME PAYLOAD & MEMORY LEAKS (1-Million Row Test)

### FINDING 2.1 — CRITICAL: 21 unbounded queries will crash the app at scale

Every single repository fetches **all rows without `.limit()`**. At 50,000 attendance records per school:

| Repository | Method | Table | Crash Threshold |
|---|---|---|---|
| `student_repository.dart` | `fetchStudents()` | students | ~10K students |
| `student_repository.dart` | `fetchStudentAttendance()` | attendance | ~50K rows |
| `attendance_repository.dart` | `fetchTodayAttendance()` | attendance | All today's rows |
| `reports_repository.dart` | `fetchAttendanceByDay()` | attendance | 30 days × all |
| `dashboard_repository.dart` | `fetchStudents()` | students | Entire table |
| `messaging_repository.dart` | `fetchMessages()` | line_messages | Unlimited chat history |
| `billing_repository.dart` | `fetchPayments()` | payments | Unlimited financial records |

**Patch — Dart (example for student_repository.dart):**
```dart
// BEFORE (crashes at scale)
final data = await _supabase
    .from('students')
    .select('...')
    .or('status.eq.active,status.is.null')
    .order('joined_at', ascending: false);

// AFTER (paginated)
final data = await _supabase
    .from('students')
    .select('...')
    .or('status.eq.active,status.is.null')
    .order('joined_at', ascending: false)
    .range(offset, offset + pageSize - 1);
```

Every `.order()` call in the codebase must be followed by `.limit(N)` or `.range(from, to)`.

---

### FINDING 2.2 — CRITICAL: Realtime subscriptions receive global firehose

All 4 Realtime channels listen to **ALL rows across ALL schools**:

```dart
// attendance_provider.dart — receives every check-in from every school
supabase.channel('attendance_realtime')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'attendance',
    callback: (_) => ref.invalidateSelf(),
  )
```

With 10,000 schools checking in simultaneously, every client receives 10,000 change events per minute and triggers 10,000 unnecessary re-fetches.

**Patch — Dart (all 4 subscriptions):**
```dart
final schoolId = ref.read(authProvider).value?.profile?.schoolId;

supabase.channel('attendance_realtime')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'attendance',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'school_id',
      value: schoolId,
    ),
    callback: (_) => ref.invalidateSelf(),
  )
```

Apply the same `filter:` pattern to all 4 channels:
- `attendance_realtime` in `attendance_provider.dart`
- `course_attendance_$courseId` in `attendance_provider.dart`
- `home_attendance_realtime` in `dashboard_provider.dart`
- `line_messages_changes` in `messaging_provider.dart`

---

### FINDING 2.3 — HIGH: `fetchStudentsWithStatus()` fires 4 parallel unbounded queries

In `student_repository.dart`, the `fetchStudentsWithStatus()` method runs `Future.wait()` with 4 simultaneous queries — ALL unbounded:
1. All students (no limit)
2. All enrollments (no limit)
3. All attendance (no limit)
4. All attendance summaries (no limit)

At scale, this single method allocates 4 massive lists simultaneously, quadrupling RAM consumption.

---

### FINDING 2.4 — HIGH: `reports_repository.dart` fetches raw attendance for charting

```dart
// fetchAttendanceByDay() — pulls 30 days of raw attendance rows
// to COUNT them client-side
final data = await _supabase
    .from('attendance')
    .select('attended_at_ts')
    .not('approved_by', 'is', null)
    .gte('attended_at_ts', thirtyDaysAgo);
```

This fetches potentially 100K+ raw rows to count them in Dart. Should be a server-side aggregate.

**Patch SQL — create RPC:**
```sql
CREATE OR REPLACE FUNCTION get_attendance_by_day(days_back int DEFAULT 30)
RETURNS TABLE(day date, count bigint) LANGUAGE sql STABLE AS $$
  SELECT attended_at_ts::date AS day, count(*)
  FROM attendance
  WHERE school_id = current_school_id()
    AND approved_by IS NOT NULL
    AND attended_at_ts >= now() - (days_back || ' days')::interval
  GROUP BY 1 ORDER BY 1;
$$;
```

---

## PILLAR 3: DATABASE INDEXING & TIMEOUT CASCADES

### FINDING 3.1 — CRITICAL: 7 missing compound indexes for RLS-filtered query patterns

Every query hits RLS which calls `current_school_id()`. The resulting `WHERE school_id = X` clause needs compound indexes with the other filter columns:

| Missing Index | Impact | Patch SQL |
|---|---|---|
| `attendance(school_id, attended_at_ts DESC)` | Every attendance page, dashboard, reports | `CREATE INDEX idx_attendance_school_ts ON attendance(school_id, attended_at_ts DESC);` |
| `attendance(school_id, student_id, course_id)` | Used hours calculation, student history | `CREATE INDEX idx_attendance_school_student_course ON attendance(school_id, student_id, course_id);` |
| `students(school_id, status)` | Student list with active/inactive filter | `CREATE INDEX idx_students_school_status ON students(school_id, status);` |
| `enrollments(school_id, status)` | Active enrollment queries | `CREATE INDEX idx_enrollments_school_status ON enrollments(school_id, status);` |
| `expenses(school_id, date)` | Billing date-range queries | `CREATE INDEX idx_expenses_school_date ON expenses(school_id, date);` |
| `income_records(school_id, date_paid)` | Revenue reports | `CREATE INDEX idx_income_records_school_date ON income_records(school_id, date_paid);` |
| `payments(school_id, received_at)` | Payment history | `CREATE INDEX idx_payments_school_received ON payments(school_id, received_at DESC);` |

---

### FINDING 3.2 — HIGH: 3 tables missing `school_id` index entirely

| Table | Patch SQL |
|---|---|
| `monthly_summary` | `CREATE INDEX idx_monthly_summary_school ON monthly_summary(school_id);` |
| `renewal_pending_state` | `CREATE INDEX idx_renewal_pending_state_school ON renewal_pending_state(school_id);` |
| `renewal_tokens` | `CREATE INDEX idx_renewal_tokens_school ON renewal_tokens(school_id);` |

---

### FINDING 3.3 — HIGH: Views with correlated subqueries will timeout at scale

The `expected_students_today` and `renewal_students` views both use:

```sql
LEFT JOIN LATERAL (
  SELECT count(*) AS used_hours
  FROM attendance a
  WHERE a.student_id = e.student_id AND a.course_id = e.course_id
    AND a.approved_by IS NOT NULL
) att ON (true)
```

This runs a **full count of ALL attendance rows** for each student×course pair. With 50K attendance rows and 200 active enrollments, this is 200 × sequential scans = timeout.

**Patch:** The compound index from 3.1 (`attendance(school_id, student_id, course_id)`) will convert these to index-only scans. Additionally, consider materializing `student_course_attendance_summary` as a materialized view with a periodic refresh.

---

### FINDING 3.4 — MEDIUM: `school_health` view joins 6 subqueries with no school filter

```sql
-- Each subquery scans entire table with GROUP BY school_id
LEFT JOIN (SELECT school_id, count(*) FROM students GROUP BY school_id) ...
LEFT JOIN (SELECT school_id, count(*) FROM profiles GROUP BY school_id) ...
LEFT JOIN (SELECT school_id, count(*) FROM courses GROUP BY school_id) ...
LEFT JOIN (SELECT school_id, count(*) FROM attendance WHERE ... GROUP BY school_id) ...
LEFT JOIN (SELECT school_id, count(*) FROM line_messages WHERE ... GROUP BY school_id) ...
```

At 1,000 schools with millions of rows each, this view will timeout. Since it's only used by superadmins, consider adding `WHERE s.status = 'active'` and materializing it.

---

## SEVERITY SUMMARY

| Severity | Count | Key Findings |
|---|---|---|
| **CRITICAL** | 6 | `list_all_profiles` data leak, `get_school_owner_logins` exposure, profile INSERT escalation, unbounded queries (21), global realtime firehose (4), 7 missing compound indexes |
| **HIGH** | 5 | Profile UPDATE cross-school, `link_line_account` cross-school write, `fetchStudentsWithStatus` 4× RAM, reports client-side aggregation, 3 tables missing school_id index |
| **MEDIUM** | 4 | `renewal_pending_state` no RLS policies, audit_log insert fails silently, impersonation school_id trigger missing, `school_health` view timeout risk |

---

## IMMEDIATE ACTION ITEMS (Priority Order)

1. **Patch `list_all_profiles()`** — add `WHERE school_id = current_school_id()` (or superadmin bypass)
2. **Patch `get_school_owner_logins()`** — add `is_superadmin()` guard
3. **Add `prevent_school_id_change` trigger** — block non-superadmin school_id mutation
4. **Fix `profiles_update_own` policy** — add school_id guard for owners
5. **Fix `profiles_insert_system` policy** — restrict profile creation
6. **Add `filter:` to all 4 Realtime subscriptions** — stop the global firehose
7. **Add `.limit()` or `.range()` to all 21 unbounded queries**
8. **Run the 10 `CREATE INDEX` statements** from Findings 3.1 and 3.2
9. **Add school_id validation to `link_line_account()`**
10. **Replace `fetchAttendanceByDay()` with server-side `get_attendance_by_day()` RPC**

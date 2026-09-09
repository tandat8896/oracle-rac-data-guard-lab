# Problem Log — Query Tuning Lab

## Problem 1: PGA Overalloc (phát hiện khi chuẩn bị chạy parallel)

**Ngày:** 09/06/2026

**Triệu chứng:** `total PGA inuse (689MB) > pga_aggregate_target (512MB)`, `overalloc_count = 3`, `total freeable PGA memory = 57MB`.

**Phát hiện khi:** Check `v$pgastat` trước khi chạy `/*+ PARALLEL(2) */`.

**Nguyên nhân:** CDB root target 512MB quá thấp, RAC Multitenant yêu cầu PDB ≤ CDB root.

**Fix:**
```sql
ALTER SESSION SET CONTAINER = CDB$ROOT;
ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 2G;
ALTER SYSTEM SET PGA_AGGREGATE_LIMIT = 4G;
ALTER SESSION SET CONTAINER = PDB1;
ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 1G;
ALTER SYSTEM SET PGA_AGGREGATE_LIMIT = 4G;
```

**Kết quả:** `overalloc_count = 0`, inuse (689MB) < target (2048MB).

**Bài học:** Luôn check PGA trước parallel. PDB không thể > CDB root.

---

## Problem 2:

**Ngày:**

**Triệu chứng:**

**Phát hiện khi:**

**Nguyên nhân:**

**Fix:**

**Kết quả:**

**Bài học:**

---

## Problem 3:

**Ngày:**

**Triệu chứng:**

**Phát hiện khi:**

**Nguyên nhân:**

**Fix:**

**Kết quả:**

**Bài học:**

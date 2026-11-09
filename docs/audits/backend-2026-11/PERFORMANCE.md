# Performance

## Method

`scripts/bench-workspace.ts` is committed and reproducible:

```sh
BENCH_DATABASE_URL=postgres://…/scratch npx tsx scripts/bench-workspace.ts
```

It creates and drops its own schema, applies the workspace migrations and
drives the real `putWorkspace` and `getWorkspace` against PostgreSQL. It
refuses database names that look like real ones.

**Environment and settings.**

- **Runtime and database:** Node 22.23.4 and PostgreSQL 18.4
  (`postgres:18.4-alpine`), both local in the same container.
- **Concurrency:** pool `max` 8.
- **Workload:** 40 synthetic members, each with 300 history sessions (a
  399,396-byte workspace, which is a heavy member).
- **Sequential phase:** one member, 30 warm-up operations excluded, then 300
  measured saves and 300 measured reads.
- **Concurrent phase:** 400 saves across the 40 members, 8 in flight, never two
  for the same member at once.
- **Comparison:** the baseline (`53c4877`) and final code ran back to back,
  twice, on a quiet machine.

**Limits.** This is in-process, so it measures validation, fingerprinting,
serialisation and PostgreSQL. It does not include HTTP, Fastify, session
lookup, the Worker or the Tunnel. The production API runs Node 26 on a 2 GB
host, so absolute numbers will differ there.

## Results (milliseconds; round 1 / round 2)

| Metric                | Before            | After             | Change                    |
| --------------------- | ----------------- | ----------------- | ------------------------- |
| Sequential save p50   | 104.8 / 109.2     | 103.5 / 96.8      | −1% / −11%                |
| Sequential save p95   | 130.4 / 131.7     | 119.9 / 118.7     | −8% / −10%                |
| Sequential save p99   | 140.3 / 136.6     | 126.3 / 127.4     | −10% / −7%                |
| Read p50              | 28.4 / 26.2       | 30.6 / 26.3       | No change (not targeted)  |
| Concurrent save p50   | 512.5 / 475.2     | 376.3 / 336.1     | −27% / −29%               |
| Concurrent save p95   | 717.4 / 668.2     | 524.5 / 465.6     | −27% / −30%               |
| Concurrent save p99   | 792.8 / 784.5     | 612.4 / 540.3     | −23% / −31%               |
| Concurrent throughput | 15.2 / 16.8 /s    | 20.9 / 23.4 /s    | +37% / +39%               |
| Errors                | 0 / 0             | 0 / 0             | —                         |
| Process RSS at end    | 330.0 / 326.4 MiB | 361.9 / 344.1 MiB | +32 / +18 MiB (see below) |

## Where the time went (CPU profile of one 400 KB save, before the change)

| Step                                     | Mean     |
| ---------------------------------------- | -------- |
| Full workspace validation (zod)          | 17.95 ms |
| Sorted-key request fingerprint + SHA-256 | 22.81 ms |
| `JSON.stringify`                         | 3.16 ms  |
| Starter workspace build per save         | 0.38 ms  |
| Read-path validation (GET)               | 20.68 ms |

The change removes the sorted-key fingerprint (B-13). It now hashes the
canonical parsed JSON. The starter workspace is now built only on a member's
first write. Validation is unchanged, because it is a security boundary.

The concurrent phase gains most because the fingerprint is synchronous CPU
work that blocked the event loop while other saves waited.

## Caveats

- **RSS is a single end-of-run sample.** It reflects the V8 heap at that
  moment, not peak or steady-state usage. The difference was not investigated
  further and is reported as observed.
- **Reads still validate on every request (about 20 ms at 400 KB).** Skipping
  that would be the next large saving, but it would change a deliberate
  design decision from the October audit, so it is not done here.
- **The retention `DELETE` plan at 1,000 operations per member was not
  measured** (D-10).

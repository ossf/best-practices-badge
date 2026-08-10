# Memory Growth Investigation Tools

This document describes the tools available for investigating memory growth
in the Best Practices Badge application, and documents the results of
a memory investigation in January 2026.

## Overview

The application includes several tools for diagnosing memory issues:

1. **GC Compact Thread Diagnostics** - Enhanced logging during garbage
   collection compaction (built in to `lib/gc_compact_thread.rb`)
2. **Memory Stress Test Script** - Simulates production traffic patterns
   (`script/memory_stress_test.rb`)
3. **Memory Monitor Script** - Real-time memory monitoring of rails server
   (`script/monitor_memory.rb`)

## Prerequisites

### Disable Rate Limiting for Development

Rate limiting is now disabled in development mode by default (only enabled in
production). This allows stress testing without hitting throttle limits.

See `config/initializers/rack_attack.rb` - throttles use
`if Rails.env.production?`.

### Install Dependencies

The `memory_profiler` gem is included in the development group:

```bash
bundle install
```

### Path Files for Realistic Traffic

The stress test script uses `requested-paths-*.txt` files in the project
root for realistic production request paths. Create these from production
logs:

```bash
# Extract GET request paths from logs
grep 'GET ' production.log | awk '{print $PATH_COLUMN}' > requested-paths-001.txt
```

Verify path files exist before running tests:

```bash
ls requested-paths-*.txt
```

## Tools

### 1. GC Compact Thread Diagnostics

The `lib/gc_compact_thread.rb` module runs periodic garbage collection and
compaction. It now logs detailed diagnostics including:

- String size distribution (bucketed by size ranges)
- Frozen vs unfrozen string counts and memory
- Large string samples (>50KB) with previews
- Growth delta between compaction cycles
- Rails cache statistics

**Configuration via environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `BADGEAPP_MEMORY_COMPACTOR_MB` | 1024 | Memory threshold (MB) to trigger compaction |
| `BADGEAPP_SLEEP_AFTER_CHECK` | 60 | Seconds between memory checks |
| `BADGEAPP_SLEEP_AFTER_COMPACT` | 1200 | Seconds to wait after compaction |
| `BADGEAPP_ANNOUNCE_GC_CHECK` | unset | If set, log every memory check |

**Example - frequent compaction for testing with allocation tracing:**

```bash
BADGEAPP_MEMORY_COMPACTOR_MB=200 BADGEAPP_SLEEP_AFTER_COMPACT=180 BADGEAPP_TRACE_ALLOCATIONS=true rails s -p 3000
```

**Diagnostic output in logs:**

```text
GC.compact - String size distribution: {"0-100"=>500000, "101-1K"=>50000, ...}
GC.compact - Frozen strings: 400000 (200MB)
GC.compact - Unfrozen strings: 150000 (150MB)
GC.compact - String delta since last: count +5000, bytes +2000000
GC.compact - Cache entries: 500, size: 50000000, max: 134217728
```

### 2. Memory Stress Test Script

`script/memory_stress_test.rb` - Sends repeated GET requests to simulate
production traffic. Supports both iteration-based and duration-based modes.

**Usage:**

```bash
script/memory_stress_test.rb [options] [iterations] [base_url]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--duration DURATION` | Run for specified duration (e.g., `30s`, `10m`, `6h`, `1d`) |
| `--shuffle` | Randomize path order (recommended for realistic traffic) |
| `--no-shuffle` | Use sequential path order |
| `--report-interval N` | Report progress every N requests (default: 100) |

**Path sources (in order):**

1. Files matching `requested-paths-*.txt` in project root (real production
   paths, one per line)
2. Generated paths cycling through projects and sections

**Examples:**

```bash
# Iteration-based (original behavior)
script/memory_stress_test.rb 5000 http://localhost:3000

# Duration-based with shuffling (most realistic)
script/memory_stress_test.rb --duration 6h --shuffle

# Quick 10-minute test
script/memory_stress_test.rb --duration 10m

# More frequent reporting
script/memory_stress_test.rb --duration 6h --report-interval 50
```

**Output shows:**

- Progress with memory readings at report intervals
- Source indicator (FILE or GEN) for each path
- Hourly summaries for long-duration runs
- Final summary with memory growth statistics
- Press Ctrl+C for graceful shutdown with summary

### 3. Memory Monitor Script

`script/monitor_memory.rb` - Monitors Rails server process memory in
real-time.

**Usage:**

```bash
script/monitor_memory.rb [pid] [interval_seconds]
```

If PID is not provided, attempts to auto-detect Rails/Puma process.

**Example:**

```bash
# Monitor with 5-second intervals (auto-detect PID)
script/monitor_memory.rb

# Monitor specific PID with 10-second intervals
script/monitor_memory.rb 12345 10
```

**Output shows:**

- RSS and swap memory usage
- Delta from previous reading
- Growth rate summary on exit (Ctrl+C)

## Running a Long-Duration Stress Test (6 Hours)

For thorough memory leak investigation, run a 6-hour stress test to
capture long-term memory behavior and multiple GC compaction cycles.

### Step 1: Prepare the Environment

Ensure path files exist for realistic traffic:

```bash
ls requested-paths-*.txt
```

Clear old logs:

```bash
rm -f log/development.log
```

### Step 2: Start the Rails Server

Use a lower memory threshold for more frequent diagnostic output:

```bash
BADGEAPP_MEMORY_COMPACTOR_MB=300 BADGEAPP_SLEEP_AFTER_COMPACT=600 rails s -p 3000
```

This triggers GC.compact diagnostics more frequently (every ~300MB growth
instead of 1GB).

### Step 3: Start Memory Monitoring (Terminal 2)

Optional but recommended for real-time visibility:

```bash
script/monitor_memory.rb
```

### Step 4: Run the 6-Hour Stress Test (Terminal 3)

```bash
script/memory_stress_test.rb --duration 6h --shuffle http://localhost:3000
```

The script will:

- Cycle through production paths from `requested-paths-*.txt` files
- Reshuffle paths when all have been used
- Print progress every 100 requests
- Print hourly summaries with memory growth trends
- Handle Ctrl+C gracefully with a final summary

### Step 5: Monitor Progress

During the test, you can check GC.compact diagnostics in another terminal:

```bash
# View recent diagnostic output
grep 'GC\.compact' log/development.log | tail -50

# Watch diagnostics in real-time
tail -f log/development.log | grep 'GC\.compact'
```

### Step 6: Analyze Results

After the test completes (or after Ctrl+C), analyze the output for:

1. **Memory growth trends** - Is memory stabilizing or continuously growing?
2. **String count/bytes delta** - Are strings accumulating between compactions?
3. **pages_freed values** - Should be > 0; consistently 0 indicates fragmentation
4. **Large string previews** - What content is being retained?
5. **Hourly summaries** - Is the growth rate accelerating, stable, or declining?

## Interpreting Results

### Normal Behavior

- Memory grows during warmup, then stabilizes
- GC.compact reports `pages_freed > 0`
- String counts fluctuate but don't trend upward

### Potential Leak Indicators

- Memory grows continuously without stabilizing
- `pages_freed: 0` consistently
- String counts or bytes trend upward between compactions
- Large unfrozen strings accumulating
- Cache size approaching or exceeding max

## Related Files

- `lib/gc_compact_thread.rb` - GC compaction and diagnostics
- `config/initializers/gc_compact_thread.rb` - Thread startup
- `script/memory_stress_test.rb` - Load testing script
- `script/monitor_memory.rb` - Memory monitoring script

## Investigation Results (January 2026)

### Diagnosis: Ruby Heap Fragmentation (NOT a Memory Leak)

After running 6-hour stress tests while using the default memory allocator
(glibc), the diagnosis is clear: the memory growth
is **Ruby heap fragmentation**, not a memory leak.

### Evidence

| Metric | Start | End (under load) | After load stopped |
|--------|-------|------------------|-------------------|
| RSS Memory | 314 MB | 917.5 MB | Stable at ~917 MB |
| String Count | ~218K | ~565K | Stable at ~565K |
| String Bytes | 36 MB | 261 MB | Stable at 261 MB |
| pages_freed | 0 | 0 | 0 |

**Key observations:**

1. **Memory use triggered by requests** - String counts stabilized
   when load stopped.
2. **Memory pages are NOT freed** - `pages_freed: 0` consistently means Ruby
   cannot return heap pages to the OS.
3. **Not markdown processor-specific** - Problem occurs with
   both commonmarker and redcarpet processors.

### Root Cause

Ruby's memory management causes fragmentation in long-running processes:

1. Short-lived strings (response bodies ~200KB) share heap pages with
   long-lived strings (I18n translations, cached fragments, compiled templates)
2. When short-lived strings are collected, they leave "holes" on pages
3. Pages cannot be returned to OS because surviving objects are scattered
4. Under high load, allocation rate exceeds collection rate, forcing heap
   expansion
5. Once expanded, heap pages stay allocated even when mostly empty

**This is expected Ruby behavior, not a bug in this application.**

### Solution: mimalloc Memory Allocator

We tested **mimalloc** as an alternative to glibc malloc.
Mimalloc is an allocator specifically designed for language that use
reference counted objects (like Lean, Python, and Ruby).

Results show significant improvement:

| Metric | glibc malloc | mimalloc | Improvement |
|--------|--------------|----------|-------------|
| Final RSS | 917.5 MB | 714.6 MB | **-203 MB (22% lower)** |
| Memory Growth | 603 MB | 405 MB | **-198 MB (33% less)** |
| Final String Count | ~565K | ~534K | -31K (5.5% fewer) |
| Final String Bytes | 261 MB | 215 MB | -46 MB (18% less) |

**Why mimalloc instead of jemalloc?**

The jemalloc allocator is often recommended for Rails applications.
However, the jemalloc allocator has been archived on GitHub, and it appears
all jemalloc work has ceased. They mentioned mimalloc as an alternative.

**mimalloc** (Microsoft's memory allocator) is:

- Actively maintained
- Available on Ubuntu 24 as a standard system package as `libmimalloc2.0`
- Designed for better performance and reduced fragmentation, especially
  for systems that use reference counting (like Lean, Python, and Ruby).
- Drop-in replacement via `LD_PRELOAD`

### Testing mimalloc Locally

After `apt install libmimalloc2.0` we can test using mimalloc with:

```bash
sudo apt install libmimalloc2.0
LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libmimalloc.so.2.1 rails s
```

### Other Optimizations Considered

The application already has significant optimizations:

- **Markdown processing** - Regex shortcuts skip processor ~90% of the time
- **Fragment caching** - 3 cache levels per criterion
- **Cache bounded** - 128 MB limit prevents unbounded growth
- **Frozen string literals** - Enabled project-wide
- **MALLOC_ARENA_MAX=2** - Set in production per Heroku recommendation

No other easy wins were identified. The remaining memory growth is inherent
to Rails request processing (template rendering, response assembly,
ActiveRecord operations).

# Hamlit Performance Optimization Report

**Date:** 2026-03-25
**Base version:** v4.0.0 (commit 9677846)
**Ruby:** 4.0.0 +YJIT
**Platform:** darwin arm64

## Changes

### 1. `hyphenate()` - Direct char buffer manipulation (ext/hamlit/hamlit.c)

Replaced `rb_str_update(str, i, 1, str_hyphen)` with direct C buffer write via `RSTRING_PTR(str)[i] = '-'`. The old approach invoked Ruby's string machinery (encoding checks, resize, GC barriers) for each underscore character. The new approach calls `rb_str_modify()` once to ensure exclusive ownership, then writes directly to the char buffer.

### 2. `rb_str_cat` over `rb_str_concat` for constant strings (ext/hamlit/hamlit.c)

In `hamlit_build_data()`, replaced `rb_str_concat(buf, str_space)` and `rb_str_concat(buf, str_equal)` with `rb_str_cat(buf, " ", 1)` and `rb_str_cat(buf, "=", 1)`. This avoids the indirection of resolving a Ruby VALUE object when the string content is a known C literal.

### 3. `is_boolean_attribute()` - Avoid `rb_str_substr` allocation (ext/hamlit/hamlit.c)

Replaced `str_eq(rb_str_substr(key, 0, 5), "data-", 5)` with `memcmp(RSTRING_PTR(key), "data-", 5)`. The old code allocated a new Ruby string (via `rb_str_substr`) just to compare a prefix. The new code checks the length and does a direct memory comparison with zero allocations.

### 4. `merge_data_attrs_i()` - Avoid `rb_str_new_cstr` per call (ext/hamlit/hamlit.c)

Replaced `rb_str_concat(rb_str_dup(key_str), rb_str_new_cstr("-"))` with `rb_str_cat(new_key, "-", 1)`. Eliminates one temporary Ruby string allocation per data attribute key.

### 5. `RubyExpression.string_literal?` - Single Ripper pass (lib/hamlit/ruby_expression.rb)

Eliminated the double Ripper invocation. Previously called `syntax_error?` (which creates a Ripper instance and parses) and then `Ripper.sexp` (which parses again). Now calls `Ripper.sexp` once and checks for `nil` return to detect syntax errors.

### 6. Dead code cleanup (ext/hamlit/hamlit.c)

Removed unused static variables (`str_equal`, `str_hyphen`, `id_prepend`, `id_tr`) and their GC registrations.

---

## Benchmarks: Speed (iterations/second)

Measured with `benchmark-ips` on Ruby 4.0.0 +YJIT, arm64.

| Operation | Baseline | Optimized | Change |
|---|---|---|---|
| `AttributeBuilder.build_data` | 430k i/s | 476k i/s | **+10.7%** |
| `AttributeBuilder.build` (full) | 333k i/s | 354k i/s | **+6.3%** |
| Compilation | 1,685 i/s | 1,716 i/s | **+1.8%** |
| Render (standard template) | 741k i/s | 741k i/s | ~0% |

The standard render benchmark uses static attributes resolved at compile time, so the C extension runtime path is not exercised. The improvement shows in `build_data` and `build` which are called when templates have truly dynamic attributes (variables, method calls).

## Benchmarks: Memory allocations (objects per call)

Measured with `ObjectSpace.count_objects`, GC disabled during measurement.

### AttributeBuilder.build_data (runtime, per call)

| Metric | Baseline | Optimized | Change |
|---|---|---|---|
| Total objects | 25 | 21 | **-16%** |
| Strings | 21 | 17 | **-19%** |
| Arrays | 3 | 3 | 0% |
| Hashes | 3 | 3 | 0% |

### AttributeBuilder.build (full, runtime, per call)

| Metric | Baseline | Optimized | Change |
|---|---|---|---|
| Total objects | 33 | 29 | **-12%** |
| Strings | 22 | 18 | **-18%** |
| Arrays | 9 | 9 | 0% |
| Hashes | 5 | 5 | 0% |

### Compilation (per call)

| Metric | Baseline | Optimized | Change |
|---|---|---|---|
| Total objects | 2,456 | 2,425 | **-1.3%** |
| Strings | 599 | 575 | **-4%** |
| Arrays | 1,503 | 1,498 | -0.3% |

### Render standard template (per call)

| Metric | Baseline | Optimized | Change |
|---|---|---|---|
| Total objects | 21 | 21 | 0% |
| Strings | 17 | 17 | 0% |

No change expected: the standard benchmark template resolves all attributes at compile time.

---

## Files modified

- `ext/hamlit/hamlit.c` - C extension optimizations (proposals 1-4, 6)
- `lib/hamlit/ruby_expression.rb` - Ripper call reduction (proposal 5)

## Test results

1096 runs, 1140 assertions, **0 failures, 0 errors**, 231 skips.

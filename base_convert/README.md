# convert.sh

**convert.sh** is a standalone Bash script for converting numbers between any two bases (2–36), with full support for integer and fractional parts, padding, grouping, prefixes, clipboard integration, and an interactive mode.

---

## 📋 Features

- **Universal Base Conversion**  
  Convert any number (integer or fractional) between bases 2 through 36.

- **Fractional Numbers**  
  Converts fractional parts with correct **rounding** (not truncation) to a configurable precision.

- **Negative & Signed Numbers**  
  Recognizes and preserves leading `-` or `+` on your input.

- **Formatting Options**  
  - **Prefixes** (`-P` / `--prefix`): add `0b`, `0o`, or `0x` for bases 2, 8, and 16.  
  - **Zero‐padding** (`-p N` / `--pad N`): pad the integer portion to width _N_.  
  - **Digit grouping** (`-g N` / `--group N`): insert underscores every _N_ digits in the integer part.  
  - **Lowercase** (`-l` / `--lowercase`): force A–Z digits to a–z.  
  - **Precision** (`-n N` / `--precision N`): set fractional‐digit count (default 10).

- **Clipboard Support** (`-c` / `--copy`)  
  Automatically copies the result to your clipboard if `xclip`, `pbcopy`, or `wl-copy` is installed.

- **Interactive Mode**  
  Just run `./convert.sh` with no arguments and follow the prompts for a guided conversion session.

- **Robust Validation & Errors**  
  - Ensures both bases are in the range 2–36.  
  - Checks that all digits in your input are valid for the specified base.  
  - Strips common `0b`/`0o`/`0x` prefixes on input for convenience.

---

## 📥 Installation

1. **Clone** or download the script:
   ```bash
   git clone https://github.com/funkybooboo/shell_practice.git
   cd shell_practice/base_convert
````

2. **Make executable**:

   ```bash
   chmod +x convert.sh
   ```

3. (Optional) **Move into your PATH**:

   ```bash
   mv convert.sh /usr/local/bin/convert
   ```

---

## ⚙️ Usage

### CLI Mode

```bash
./convert.sh <from_base> <to_base> <number> [OPTIONS]
```

* `<from_base>` and `<to_base>`: integers between `2` and `36`.
* `<number>`: the value to convert (can include a fractional part and a leading `-` or `+`).

#### Options

| Short  | Long            | Description                                            |
| ------ | --------------- | ------------------------------------------------------ |
| `-P`   | `--prefix`      | Add base prefix (`0b`, `0o`, `0x`).                    |
| `-p N` | `--pad N`       | Zero‐pad integer part to width *N*.                    |
| `-g N` | `--group N`     | Group integer digits every *N* chars with `_`.         |
| `-l`   | `--lowercase`   | Output alphabetic digits in lowercase.                 |
| `-n N` | `--precision N` | Fractional digits count (default `10`), with rounding. |
| `-c`   | `--copy`        | Copy the result to clipboard.                          |

#### Examples

```bash
# 1. Decimal → Binary
./convert.sh 10 2 15
# → 1111

# 2. Add Prefix
./convert.sh 10 2 15 --prefix
# → 0b1111

# 3. Hex → Decimal, lowercase prefix
./convert.sh 16 10 0xF --prefix --lowercase
# → 0xf

# 4. Pad & Group
./convert.sh 2 16 1101 --pad 4 --group 2 --prefix
# → 0x0D

# 5. Fractional Conversion
./convert.sh 10 8 13.625
# → 15.5

# 6. Set Precision
./convert.sh 10 3 0.5 --precision 3
# → 0.112

# 7. Negative Fractional
./convert.sh 10 16 -15.375 --prefix --lowercase
# → -0xf.6
```

---

### Interactive Mode

Run without arguments to walk through prompts:

```bash
./convert.sh
From base:       10
To base:         2
Number:          13.625
Prefix? [y/N]:   y
Pad to N (opt):  8
Group every N:   4
Lowercase? [y/N]:y
Copy? [y/N]:     n
Precision (opt): 5

# → 0b00001101.10100
```

---

## ✅ Self-Tests

A companion `test.sh` verifies core functionality and error handling:

```bash
chmod +x test.sh
./test.sh
# → All tests passed! 🎉
```

# netadmin.sh

**netadmin.sh** is an all-in-one Bash network helper for IPv4 subnet calculations, splitting, DNS lookups (with MX→A fallback), and port scanning. It outputs human-friendly text, CSV or JSON, and can be dropped straight into your automation pipelines or used interactively.

---

## 🚀 Features

- **Subnet details**  
  Calculate network address, broadcast, netmask, wildcard mask, host range, and usable hosts for any `A.B.C.D/NN`.

- **Subnet splitting**  
  Break a network into N equal subnets (requires N be a power of two) and list each CIDR.

- **DNS lookups**  
  Query A, AAAA, MX, NS or TXT records.  
  - MX queries automatically fall back to A records if no MX exist.  
  - Output formats: plain text, CSV, or JSON.

- **Port scanning**  
  Check TCP ports with either `nmap` (if installed) or Bash’s `/dev/tcp`.  
  - Default ports: 22, 80, 443  
  - Custom port list via `--ports`  
  - Output formats: plain text, CSV, or JSON.

- **Interactive mode**  
  Omit all arguments and walk through prompts for each command.

- **Self-tests**  
  A companion `test.sh` script exercises all features and checks output.

---

## 📥 Requirements

- **Bash** 4+ (for `set -o pipefail`, `[[ ]]`, arrays)
- **coreutils**: `awk`, `sed`, `printf`, `grep`
- **`dig`** or **`host`** (for DNS; either works)
- **`nmap`** (optional; if missing, falls back to `/dev/tcp`)
- **`awk`, `sed`**, and **`jq`** (optional, for processing JSON)

---

## 📂 Installation

1. Clone or download this repo.
2. Make the scripts executable:

   ```bash
   chmod +x netadmin.sh test.sh
````

3. (Optional) Move `netadmin.sh` into your `$PATH`, e.g.:

   ```bash
   mv netadmin.sh /usr/local/bin/netadmin
   ```

---

## ⚙️ Usage

```bash
netadmin.sh <command> [arguments...] [options...]
```

### Commands

| Command                         | Description                                                                                                                |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `subnet <IP>/<prefix>`          | Show network, broadcast, netmask, wildcard, first/last host, and usable-host count.                                        |
| `split <IP>/<prefix> <count>`   | Divide into `<count>` equal subnets (must be a power of two).                                                              |
| `dns <domain> [--type T]`       | Lookup DNS records. `<T>` can be `A`, `AAAA`, `MX`, `NS`, `TXT`. Default is `A`. MX queries fall back to A if no MX exist. |
| `scan <host> [--ports P1,P2..]` | Scan TCP ports. Default ports: `22,80,443`. Uses `nmap` if present, else Bash `/dev/tcp`.                                  |

### Global Options

| Option   | Description                                                 |
| -------- | ----------------------------------------------------------- |
| `--json` | Output results in JSON array.                               |
| `--csv`  | Output results in CSV format (`type,data` or `port,state`). |
| *(none)* | Default “pretty” text with colored headings.                |

### Interactive Mode

Omit all arguments to launch prompts:

```bash
netadmin.sh
```

---

## 🔧 Examples

### Subnet Details

```bash
$ netadmin.sh subnet 192.168.1.130/26
Subnet 192.168.1.130/26:
  Network      192.168.1.128/26
  Broadcast    192.168.1.191
  Netmask      255.255.255.192
  Wildcard     0.0.0.63
  First host   192.168.1.129
  Last host    192.168.1.190
  Usable       62
```

### Split into 4 Subnets

```bash
$ netadmin.sh split 192.168.1.0/24 4
Splitting 192.168.1.0/24 into 4 subnets (/26):
   1) 192.168.1.0/26
   2) 192.168.1.64/26
   3) 192.168.1.128/26
   4) 192.168.1.192/26
```

### DNS Lookup with MX→A Fallback

```bash
# example.com has no MX, so you get A records:
$ netadmin.sh dns example.com --type MX --json
[
  {"type":"A","data":"93.184.216.34"},
  {"type":"A","data":"2606:2800:220:1:248:1893:25c8:1946"}   # if AAAA included
]
```

### Port Scan (JSON)

```bash
$ netadmin.sh scan 192.168.1.1 --ports 22,80 --json
[
  {"port":22,"state":"closed"},
  {"port":80,"state":"open"}
]
```

---

## ✅ Self-Tests

Run `test.sh` to verify all commands:

```bash
./test.sh
# → “All tests passed! 🎉”
```

---

## 🛠️ Contributing

1. Fork the repo
2. Create a feature branch
3. Submit a PR with tests passing

# gh-batch-archive

**Batch archive or unarchive multiple GitHub repositories with maximum clarity, safety, and speed.**

[![MIT License](https://img.shields.io/github/license/Paul1404/gh-batch-archive)](LICENSE)

---

## ✨ Features

- **Batch archive or unarchive** any number of repositories
- **Interactive selection** (with [fzf](https://github.com/junegunn/fzf)), or fallback to a simple menu
- **Pattern filtering** to quickly narrow down your repo list
- **Dry-run mode** for safe previews
- **Parallel processing** for speed
- **Clear, explicit, and colorful messaging** at every step
- **Action logging** for auditability
- **No external dependencies** except [GitHub CLI](https://cli.github.com/) (`gh`).  
  (fzf is optional for best UX)

---

## 🚀 Quick Start

1. **Clone this repository:**

   ```bash
   git clone https://github.com/Paul1404/gh-batch-archive.git
   cd gh-batch-archive
   ```

2. **Make the script executable:**

   ```bash
   chmod +x gh-batch-archive.sh
   ```

3. **Authenticate with GitHub CLI (if you haven't already):**

   ```bash
   gh auth login
   ```

4. **Run the script!**

   ```bash
   ./gh-batch-archive.sh
   ```

---

## 🛠️ Usage

```bash
./gh-batch-archive.sh [options] [owner_or_org]
```

### **Options**

| Option             | Description                                                                 |
|--------------------|-----------------------------------------------------------------------------|
| `--unarchive`      | Unarchive instead of archive                                                |
| `--dry-run`        | Show what would be done, but don't change anything                          |
| `--pattern`        | Filter repos by substring or regex (e.g. `--pattern "test"`)                |
| `--interactive`    | Use interactive selection (fzf if available, fallback to menu)              |
| `--parallel N`     | Process up to N repos in parallel (default: 4)                              |
| `--log FILE`       | Log actions to FILE (default: `gh-batch-archive.log`)                       |
| `--help`           | Show help message                                                           |

### **Examples**

- Archive all your repositories:
  ```bash
  ./gh-batch-archive.sh
  ```

- Archive all repositories for an organization:
  ```bash
  ./gh-batch-archive.sh myorg
  ```

- Interactively select which repos to archive:
  ```bash
  ./gh-batch-archive.sh --interactive
  ```

- Filter by pattern and archive:
  ```bash
  ./gh-batch-archive.sh --pattern "test"
  ```

- Unarchive repositories (instead of archiving):
  ```bash
  ./gh-batch-archive.sh --unarchive
  ```

- Preview what would happen (dry-run):
  ```bash
  ./gh-batch-archive.sh --dry-run
  ```

- Process 8 repos in parallel:
  ```bash
  ./gh-batch-archive.sh --parallel 8
  ```

---

## 🖥️ Interactive Selection

If you have [`fzf`](https://github.com/junegunn/fzf) installed, you can interactively select multiple repositories with your keyboard.  
If not, the script will fall back to a simple numbered menu.

---

## 📋 Logging

All actions (including dry-runs) are logged to `gh-batch-archive.log` by default.  
You can specify a different log file with `--log myfile.log`.

---

## ⚠️ Safety

- **Dry-run mode** (`--dry-run`) lets you preview actions before making changes.
- **Explicit confirmation** is required before any changes are made.
- **Clear summary** of what will happen is shown before proceeding.

---

## 🧩 Requirements

- [GitHub CLI (`gh`)](https://cli.github.com/) (required)
- [fzf](https://github.com/junegunn/fzf) (optional, for best interactive experience)
- Bash 4.x or later

---

## 📝 License

[MIT](LICENSE)

---

## 🙋‍♂️ Contributing

Pull requests and suggestions are welcome!  
Feel free to open an [issue](https://github.com/Paul1404/gh-batch-archive/issues) or submit a PR.

---

## 💡 Inspiration

This tool was built to make mass archiving and unarchiving of GitHub repositories **safe, fast, and transparent** for individuals and organizations.

---

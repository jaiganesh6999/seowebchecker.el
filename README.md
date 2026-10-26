# seowebchecker.el — Website SEO Audit Tool for GNU Emacs

Official GNU Emacs package for **SEOWebChecker** ([https://seowebchecker.com/](https://seowebchecker.com/)), the privacy-first website SEO diagnostic and auditing engine.

Perform comprehensive on-page search engine optimization checks on any live website URL or local HTML/Markdown buffer directly within GNU Emacs.

---

## 🚀 Features

- **Audit Remote URLs**: `M-x seowebchecker-audit-url` prompts for any URL (defaulting to `https://seowebchecker.com/`) and renders an on-page SEO diagnostic report.
- **Audit Local Buffers**: `M-x seowebchecker-audit-buffer` analyzes HTML files, Markdown documents, or exported web drafts before you publish.
- **Key SEO Checks**:
  - **Meta Elements**: Title tag (length & presence), Meta description (optimal length & presence).
  - **Heading Structure**: H1 hierarchy (ensuring single primary H1) and H2/H3 subheadings.
  - **Indexing Directives**: Canonical URL links and robots meta directives.
  - **Mobile & Social**: Viewport configuration, OpenGraph tags (`og:title`, `og:description`, `og:image`), and Twitter Card directives.
  - **Accessibility**: Image `alt` tags and missing description detector.
  - **Security**: HTTPS / SSL protocol validation.
- **Interactive Report Buffer**:
  - Categorized display with color-coded status pills: `[PASS]`, `[WARN]`, `[FAIL]`, and `[INFO]`.
  - Built-in shortcuts to re-run (`r`), audit new URLs (`u`), or open full interactive visual reports in your browser (`o`).

---

## 📦 Installation

### From MELPA (Recommended)

Once merged into MELPA, install using Emacs package manager:

```elisp
M-x package-install RET seowebchecker RET
```

Or via `use-package`:

```elisp
(use-package seowebchecker
  :ensure t
  :bind (("C-c s u" . seowebchecker-audit-url)
         ("C-c s b" . seowebchecker-audit-buffer)))
```

### Manual Installation

Clone this repository and add it to your `load-path`:

```elisp
(add-to-list 'load-path "~/.emacs.d/site-lisp/seowebchecker.el")
(require 'seowebchecker)
```

---

## ⌨️ Usage

| Command | Keybinding | Description |
| :--- | :--- | :--- |
| `seowebchecker-audit-url` | `u` (in report) | Prompt for a website URL and run an SEO audit |
| `seowebchecker-audit-buffer` | `b` (in report) | Audit the current active buffer (HTML/Markdown/Org) |
| `seowebchecker-open-report` | `o` (in report) | Open interactive graphical report on SEOWebChecker |
| `seowebchecker-rerun` | `r` (in report) | Re-run the audit on the last target |
| `quit-window` | `q` (in report) | Close the audit report buffer |

---

## 🔗 Links

- **SEOWebChecker Platform**: [https://seowebchecker.com/](https://seowebchecker.com/)
- **License**: GNU General Public License v3 or later (GPLv3+)

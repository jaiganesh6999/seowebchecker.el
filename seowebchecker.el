;;; seowebchecker.el --- Website SEO audit tool for Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 SEOWebChecker

;; Author: SEOWebChecker <support@seowebchecker.com>
;; Maintainer: Jai Ganesh <jaiganesh6999@gmail.com>
;; Version: 1.0.0
;; Package-Requires: ((emacs "26.1"))
;; Keywords: comm, tools, hypermedia
;; URL: https://seowebchecker.com/

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; `seowebchecker.el' provides comprehensive on-page search engine optimization
;; (SEO) diagnostics and auditing directly inside GNU Emacs.
;;
;; Features:
;; - Audit remote URLs with `M-x seowebchecker-audit-url'.
;; - Audit local HTML, Markdown, or Org buffers with `M-x seowebchecker-audit-buffer'.
;; - Checks title tags, meta descriptions, canonical URLs, viewport,
;;   OpenGraph tags, Twitter Cards, heading hierarchy (H1-H3), image alt
;;   attributes, language definitions, and HTTPS security.
;; - Displays audit results in a dedicated interactive `*SEOWebChecker Audit*' buffer.
;; - Quick jump to full interactive visual reports on https://seowebchecker.com/.

;;; Code:

(require 'url)
(require 'url-http)

(defgroup seowebchecker nil
  "Website SEO audit tool powered by SEOWebChecker."
  :group 'tools
  :prefix "seowebchecker-")

(defcustom seowebchecker-service-url "https://seowebchecker.com/"
  "Canonical URL of the SEOWebChecker platform."
  :type 'string
  :group 'seowebchecker)

(defcustom seowebchecker-title-min-length 30
  "Minimum recommended length for HTML page title."
  :type 'integer
  :group 'seowebchecker)

(defcustom seowebchecker-title-max-length 60
  "Maximum recommended length for HTML page title."
  :type 'integer
  :group 'seowebchecker)

(defcustom seowebchecker-description-min-length 120
  "Minimum recommended length for meta description."
  :type 'integer
  :group 'seowebchecker)

(defcustom seowebchecker-description-max-length 160
  "Maximum recommended length for meta description."
  :type 'integer
  :group 'seowebchecker)

(defface seowebchecker-pass-face
  '((t :inherit success))
  "Face used for passing SEO checks."
  :group 'seowebchecker)

(defface seowebchecker-warn-face
  '((t :inherit warning))
  "Face used for warning SEO checks."
  :group 'seowebchecker)

(defface seowebchecker-fail-face
  '((t :inherit error))
  "Face used for failing SEO checks."
  :group 'seowebchecker)

(defface seowebchecker-info-face
  '((t :inherit font-lock-keyword-face))
  "Face used for informational SEO tags."
  :group 'seowebchecker)

(defvar-local seowebchecker-last-target nil
  "Last audited target URL or buffer name.")

(defvar-local seowebchecker-last-target-type nil
  "Type of last audited target ('url or 'buffer).")

(defvar seowebchecker-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "r") #'seowebchecker-rerun)
    (define-key map (kbd "u") #'seowebchecker-audit-url)
    (define-key map (kbd "b") #'seowebchecker-audit-buffer)
    (define-key map (kbd "o") #'seowebchecker-open-report)
    map)
  "Keymap for `seowebchecker-mode'.")

(define-derived-mode seowebchecker-mode special-mode "SEOWebChecker"
  "Major mode for displaying website SEO audit results.

\\{seowebchecker-mode-map}"
  (setq truncate-lines t)
  (setq buffer-read-only t))

(defun seowebchecker--extract-tag-content (tag html)
  "Extract the inner text of TAG from HTML string.
Return nil if TAG is not found."
  (let ((pattern (format "<%s[^>]*>\\([\\s\\S]*?\\)</%s>" tag tag)))
    (when (string-match pattern html)
      (string-trim (match-string 1 html)))))

(defun seowebchecker--extract-meta (name-or-prop html)
  "Extract content attribute of meta tag matching NAME-OR-PROP from HTML.
Matches either name=\"...\" or property=\"...\"."
  (let ((pattern1 (format "<meta[^>]+(?:name|property)=[\"']%s[\"'][^>]+content=[\"']\\([^\"']*\\)[\"']"
                          (regexp-quote name-or-prop)))
        (pattern2 (format "<meta[^>]+content=[\"']\\([^\"']*\\)[\"'][^>]+(?:name|property)=[\"']%s[\"']"
                          (regexp-quote name-or-prop))))
    (cond
     ((string-match pattern1 html) (match-string 1 html))
     ((string-match pattern2 html) (match-string 1 html))
     (t nil))))

(defun seowebchecker--count-tags (tag html)
  "Count occurrences of opening TAG in HTML string."
  (let ((count 0)
        (pos 0)
        (pattern (format "<%s\\(?:[\\s>][^>]*\\)?>" tag)))
    (while (string-match pattern html pos)
      (setq count (1+ count))
      (setq pos (match-end 0)))
    count))

(defun seowebchecker--count-images-missing-alt (html)
  "Count images missing alt attribute in HTML string."
  (let ((count 0)
        (pos 0)
        (img-pattern "<img\\s-+[^>]*>"))
    (while (string-match img-pattern html pos)
      (let ((tag-str (match-string 0 html)))
        (unless (string-match "alt=[\"'][^\"']*[\"']" tag-str)
          (setq count (1+ count))))
      (setq pos (match-end 0)))
    count))

(defun seowebchecker--extract-canonical (html)
  "Extract href of canonical link tag from HTML."
  (let ((pattern1 "<link[^>]+rel=[\"']canonical[\"'][^>]+href=[\"']\\([^\"']*\\)[\"']")
        (pattern2 "<link[^>]+href=[\"']\\([^\"']*\\)[\"'][^>]+rel=[\"']canonical[\"']"))
    (cond
     ((string-match pattern1 html) (match-string 1 html))
     ((string-match pattern2 html) (match-string 1 html))
     (t nil))))

(defun seowebchecker--analyze-html (html url-or-name is-url)
  "Analyze HTML string for target URL-OR-NAME.
IS-URL indicates if the target is a remote web URL.
Returns a list of diagnostic result plists."
  (let* ((title (seowebchecker--extract-tag-content "title" html))
         (title-len (if title (length title) 0))
         (desc (seowebchecker--extract-meta "description" html))
         (desc-len (if desc (length desc) 0))
         (canonical (seowebchecker--extract-canonical html))
         (viewport (seowebchecker--extract-meta "viewport" html))
         (robots (seowebchecker--extract-meta "robots" html))
         (og-title (seowebchecker--extract-meta "og:title" html))
         (og-desc (seowebchecker--extract-meta "og:description" html))
         (og-img (seowebchecker--extract-meta "og:image" html))
         (tw-card (seowebchecker--extract-meta "twitter:card" html))
         (h1-count (seowebchecker--count-tags "h1" html))
         (h2-count (seowebchecker--count-tags "h2" html))
         (h3-count (seowebchecker--count-tags "h3" html))
         (total-imgs (seowebchecker--count-tags "img" html))
         (missing-alt (seowebchecker--count-images-missing-alt html))
         (results nil))

    ;; 1. Title Tag
    (cond
     ((null title)
      (push (list :category "Meta" :label "Page Title" :status :fail
                  :detail "Missing <title> tag in HTML document.") results))
     ((or (< title-len seowebchecker-title-min-length)
          (> title-len seowebchecker-title-max-length))
      (push (list :category "Meta" :label "Page Title" :status :warn
                  :detail (format "\"%s\" (%d chars). Optimal length is %d-%d characters."
                                  title title-len
                                  seowebchecker-title-min-length
                                  seowebchecker-title-max-length)) results))
     (t
      (push (list :category "Meta" :label "Page Title" :status :pass
                  :detail (format "\"%s\" (%d chars). Good length." title title-len)) results)))

    ;; 2. Meta Description
    (cond
     ((null desc)
      (push (list :category "Meta" :label "Meta Description" :status :fail
                  :detail "Missing <meta name=\"description\"> tag.") results))
     ((or (< desc-len seowebchecker-description-min-length)
          (> desc-len seowebchecker-description-max-length))
      (push (list :category "Meta" :label "Meta Description" :status :warn
                  :detail (format "\"%s\" (%d chars). Optimal is %d-%d characters."
                                  desc desc-len
                                  seowebchecker-description-min-length
                                  seowebchecker-description-max-length)) results))
     (t
      (push (list :category "Meta" :label "Meta Description" :status :pass
                  :detail (format "\"%s\" (%d chars). Optimal length." desc desc-len)) results)))

    ;; 3. Heading Structure
    (cond
     ((= h1-count 0)
      (push (list :category "Headings" :label "H1 Heading" :status :fail
                  :detail "No <h1> heading found on page. Exactly one primary <h1> is recommended.") results))
     ((> h1-count 1)
      (push (list :category "Headings" :label "H1 Heading" :status :warn
                  :detail (format "Found %d <h1> headings. Single primary <h1> heading is recommended." h1-count)) results))
     (t
      (push (list :category "Headings" :label "H1 Heading" :status :pass
                  :detail "Exactly one primary <h1> heading found.") results)))

    (push (list :category "Headings" :label "Subheadings" :status :info
                :detail (format "%d <h2> headings, %d <h3> headings found." h2-count h3-count)) results)

    ;; 4. Canonical URL
    (if canonical
        (push (list :category "Indexing" :label "Canonical URL" :status :pass
                    :detail (format "Declared canonical link: %s" canonical)) results)
      (push (list :category "Indexing" :label "Canonical URL" :status :warn
                  :detail "No canonical URL link tag declared.") results))

    ;; 5. Viewport / Mobile
    (if viewport
        (push (list :category "Mobile" :label "Mobile Viewport" :status :pass
                    :detail (format "Declared viewport: %s" viewport)) results)
      (push (list :category "Mobile" :label "Mobile Viewport" :status :fail
                  :detail "Missing <meta name=\"viewport\"> tag for mobile optimization.") results))

    ;; 6. Robots Tag
    (if robots
        (push (list :category "Indexing" :label "Robots Meta" :status :info
                    :detail (format "Declared robots: %s" robots)) results)
      (push (list :category "Indexing" :label "Robots Meta" :status :pass
                    :detail "No restrictive robots meta directive (standard indexing allowed).") results))

    ;; 7. OpenGraph Social Tags
    (if (and og-title og-desc og-img)
        (push (list :category "Social" :label "OpenGraph (OG)" :status :pass
                    :detail "Complete OpenGraph tags found (og:title, og:description, og:image).") results)
      (push (list :category "Social" :label "OpenGraph (OG)" :status :warn
                  :detail (format "Incomplete OpenGraph tags: title=%s, desc=%s, image=%s"
                                  (if og-title "yes" "missing")
                                  (if og-desc "yes" "missing")
                                  (if og-img "yes" "missing"))) results))

    ;; 8. Twitter Card
    (if tw-card
        (push (list :category "Social" :label "Twitter Card" :status :pass
                    :detail (format "Declared twitter:card: %s" tw-card)) results)
      (push (list :category "Social" :label "Twitter Card" :status :warn
                  :detail "Missing <meta name=\"twitter:card\"> tag.") results))

    ;; 9. Image Alt Attributes
    (cond
     ((= total-imgs 0)
      (push (list :category "Accessibility" :label "Image Alt Tags" :status :info
                  :detail "No <img> elements found in document.") results))
     ((= missing-alt 0)
      (push (list :category "Accessibility" :label "Image Alt Tags" :status :pass
                  :detail (format "All %d images have descriptive alt text." total-imgs)) results))
     (t
      (push (list :category "Accessibility" :label "Image Alt Tags" :status :warn
                  :detail (format "%d of %d images are missing alt text." missing-alt total-imgs)) results)))

    ;; 10. HTTPS Check (for URLs)
    (when is-url
      (if (string-prefix-p "https://" url-or-name t)
          (push (list :category "Security" :label "HTTPS / SSL" :status :pass
                      :detail "Target uses secure HTTPS protocol.") results)
        (push (list :category "Security" :label "HTTPS / SSL" :status :fail
                    :detail "Target uses insecure HTTP protocol.") results)))

    (nreverse results)))

(defun seowebchecker--render-results (target target-type results)
  "Render RESULTS for TARGET of TARGET-TYPE into the audit buffer."
  (let ((buf (get-buffer-create "*SEOWebChecker Audit*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (seowebchecker-mode)
        (setq seowebchecker-last-target target)
        (setq seowebchecker-last-target-type target-type)

        ;; Header banner
        (insert (propertize "================================================================================\n"
                            'face 'font-lock-comment-face))
        (insert (propertize " SEOWebChecker SEO Audit Report\n" 'face 'bold))
        (insert (propertize (format " Target: %s (%s)\n" target (symbol-name target-type))
                            'face 'font-lock-doc-face))
        (insert (propertize (format " Engine: SEOWebChecker (https://seowebchecker.com/)\n")
                            'face 'font-lock-comment-face))
        (insert (propertize "================================================================================\n\n"
                            'face 'font-lock-comment-face))

        ;; Summary count
        (let ((pass-count (seq-count (lambda (r) (eq (plist-get r :status) :pass)) results))
              (warn-count (seq-count (lambda (r) (eq (plist-get r :status) :warn)) results))
              (fail-count (seq-count (lambda (r) (eq (plist-get r :status) :fail)) results))
              (info-count (seq-count (lambda (r) (eq (plist-get r :status) :info)) results)))
          (insert "Summary: ")
          (insert (propertize (format " %d PASSED " pass-count) 'face 'seowebchecker-pass-face))
          (insert "  ")
          (insert (propertize (format " %d WARNINGS " warn-count) 'face 'seowebchecker-warn-face))
          (insert "  ")
          (insert (propertize (format " %d FAILS " fail-count) 'face 'seowebchecker-fail-face))
          (insert "  ")
          (insert (propertize (format " %d INFO " info-count) 'face 'seowebchecker-info-face))
          (insert "\n\n"))

        ;; Group items by category
        (let ((categories '("Meta" "Headings" "Indexing" "Mobile" "Social" "Accessibility" "Security")))
          (dolist (cat categories)
            (let ((items (seq-filter (lambda (r) (string= (plist-get r :category) cat)) results)))
              (when items
                (insert (propertize (format "--- %s ---\n" cat) 'face 'bold))
                (dolist (item items)
                  (let* ((status (plist-get item :status))
                         (label (plist-get item :label))
                         (detail (plist-get item :detail))
                         (status-str
                          (pcase status
                            (:pass (propertize "[PASS]" 'face 'seowebchecker-pass-face))
                            (:warn (propertize "[WARN]" 'face 'seowebchecker-warn-face))
                            (:fail (propertize "[FAIL]" 'face 'seowebchecker-fail-face))
                            (:info (propertize "[INFO]" 'face 'seowebchecker-info-face)))))
                    (insert (format "  %-7s  %-20s %s\n" status-str label detail))))
                (insert "\n")))))

        ;; Footer actions
        (insert (propertize "--------------------------------------------------------------------------------\n"
                            'face 'font-lock-comment-face))
        (insert (propertize " [r] Re-run audit  |  [o] Open web report  |  [u] Audit URL  |  [q] Quit\n"
                            'face 'font-lock-constant-face))
        (goto-char (point-min))))
    (pop-to-buffer buf)))

;;;###autoload
(defun seowebchecker-audit-url (url)
  "Fetch and run an on-page SEO audit on URL.
Prompt for URL with default set to `seowebchecker-service-url'."
  (interactive
   (list (read-string "Target URL to audit: " seowebchecker-service-url)))
  (message "Auditing %s with SEOWebChecker..." url)
  (let ((url-request-method "GET")
        (url-request-extra-headers '(("User-Agent" . "SEOWebChecker-Emacs/1.0.0"))))
    (url-retrieve
     url
     (lambda (status url-target)
       (if (plist-get status :error)
           (message "SEOWebChecker: Failed to fetch %s: %s"
                    url-target (plist-get status :error))
         (let ((html (buffer-string)))
           ;; Strip HTTP response headers
           (when (string-match "\r?\n\r?\n" html)
             (setq html (substring html (match-end 0))))
           (let ((results (seowebchecker--analyze-html html url-target t)))
             (seowebchecker--render-results url-target 'url results)))))
     (list url))))

;;;###autoload
(defun seowebchecker-audit-buffer (&optional buffer)
  "Run an on-page SEO audit on BUFFER or current buffer."
  (interactive)
  (let* ((target-buffer (or buffer (current-buffer)))
         (html (with-current-buffer target-buffer (buffer-string)))
         (buf-name (buffer-name target-buffer))
         (results (seowebchecker--analyze-html html buf-name nil)))
    (seowebchecker--render-results buf-name 'buffer results)))

;;;###autoload
(defun seowebchecker-open-report ()
  "Open the interactive visual audit report on SEOWebChecker in browser."
  (interactive)
  (let ((target (or seowebchecker-last-target seowebchecker-service-url)))
    (browse-url (format "%s?url=%s"
                        seowebchecker-service-url
                        (url-hexify-string target)))))

;;;###autoload
(defun seowebchecker-rerun ()
  "Re-run the audit on the last audited target."
  (interactive)
  (cond
   ((and (eq seowebchecker-last-target-type 'url) seowebchecker-last-target)
    (seowebchecker-audit-url seowebchecker-last-target))
   ((and (eq seowebchecker-last-target-type 'buffer) seowebchecker-last-target)
    (let ((buf (get-buffer seowebchecker-last-target)))
      (if (buffer-live-p buf)
          (seowebchecker-audit-buffer buf)
        (message "SEOWebChecker: Target buffer %s is no longer live." seowebchecker-last-target))))
   (t
    (seowebchecker-audit-url seowebchecker-service-url))))

(provide 'seowebchecker)

;;; seowebchecker.el ends here

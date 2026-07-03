#!/usr/bin/env bash
# docs/build-docs.sh
#
# Generates human-consumable versions of the companion document.
# Run from project root: ./docs/build-docs.sh
#
# Strategy:
# - Markdown (.md) is the primary easy-to-consume version (no build needed, great on GitHub).
# - Tries to compile LaTeX -> PDF when pdflatex is available.
# - Optionally can generate a simple HTML (future or via pandoc if present).
#
# This script is idempotent and safe to run often.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Nerdverse Documentation Builder ==="

TEX_FILE="docs/nerdverse-companion.tex"
MD_FILE="docs/nerdverse-companion.md"
PDF_FILE="docs/nerdverse-companion.pdf"
HTML_FILE="docs/nerdverse-companion.html"

# 1. Markdown is always present (source of quick consumption)
if [[ -f "$MD_FILE" ]]; then
    echo "✓ Markdown version exists: $MD_FILE"
    echo "  (This is the primary easy-to-read version. Renders on GitHub automatically.)"
else
    echo "⚠ Markdown file missing. Please ensure $MD_FILE exists."
fi

# 2. Try to build PDF from LaTeX (only if pdflatex is available)
if command -v pdflatex >/dev/null 2>&1; then
    echo
    echo "pdflatex found — attempting PDF build..."
    pushd docs > /dev/null
    
    # Run twice for TOC and references
    pdflatex -interaction=nonstopmode nerdverse-companion.tex > /dev/null 2>&1 || true
    pdflatex -interaction=nonstopmode nerdverse-companion.tex > /dev/null 2>&1 || true
    
    if [[ -f nerdverse-companion.pdf ]]; then
        mv nerdverse-companion.pdf ../docs/nerdverse-companion.pdf 2>/dev/null || true
        echo "✓ PDF generated: docs/nerdverse-companion.pdf"
    else
        echo "✗ PDF build failed (check for missing packages or errors)."
    fi
    
    # Clean up auxiliary LaTeX files
    rm -f nerdverse-companion.aux nerdverse-companion.log nerdverse-companion.out nerdverse-companion.toc 2>/dev/null || true
    
    popd > /dev/null
else
    echo
    echo "pdflatex not found — skipping PDF generation."
    echo "  On Linux: sudo apt install texlive-full   (or texlive-latex-base + extras)"
    echo "  On macOS: brew install --cask mactex"
    echo "  The .md version is still fully usable."
fi

# 3. Simple HTML generation (very basic, no external tools required)
# This creates a minimal standalone HTML wrapper around the Markdown content.
# For a better HTML, install pandoc and run: pandoc docs/nerdverse-companion.md -o docs/nerdverse-companion.html
if command -v pandoc >/dev/null 2>&1; then
    echo
    echo "pandoc found — generating nice HTML..."
    pandoc "$MD_FILE" -o "$HTML_FILE" --standalone --metadata title="The Nerdverse Companion" || true
    if [[ -f "$HTML_FILE" ]]; then
        echo "✓ HTML generated: $HTML_FILE"
    fi
else
    # Fallback: create a very basic HTML from the MD (crude but works)
    echo
    echo "Creating basic HTML fallback (no pandoc)..."
    {
        echo "<!DOCTYPE html>"
        echo "<html><head><meta charset='utf-8'>"
        echo "<title>The Nerdverse Companion</title>"
        echo "<style>body { font-family: system-ui, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; line-height: 1.6; }"
        echo "h1,h2,h3 { color: #2e7d32; } code, pre { background: #f5f5f5; padding: 2px 4px; } table { border-collapse: collapse; } td,th { border: 1px solid #ccc; padding: 4px 8px; }</style>"
        echo "</head><body>"
        echo "<h1>The Nerdverse Companion</h1>"
        echo "<p><em>Meyiu — The Sinner Who Still Chooses</em></p>"
        echo "<p><strong>Note:</strong> This is a basic fallback. For best results install <code>pandoc</code> or use the Markdown file directly.</p>"
        echo "<hr>"
        # Very crude conversion: just dump the md with minimal processing
        sed -e 's/^# \(.*\)/<h1>\1<\/h1>/' \
            -e 's/^## \(.*\)/<h2>\1<\/h2>/' \
            -e 's/^### \(.*\)/<h3>\1<\/h3>/' \
            -e 's/^---/<hr>/' \
            -e 's/\*\*\(.*\)\*\*/<strong>\1<\/strong>/g' \
            -e 's/\*\(.*\)\*/<em>\1<\/em>/g' \
            "$MD_FILE" | sed 's/$/<br>/'
        echo "</body></html>"
    } > "$HTML_FILE"
    echo "✓ Basic HTML fallback created: $HTML_FILE"
fi

echo
echo "=== Documentation build complete ==="
echo
echo "Recommended consumption:"
echo "  • GitHub / any Markdown viewer → docs/nerdverse-companion.md  (best everyday)"
echo "  • PDF (when available)        → docs/nerdverse-companion.pdf"
echo "  • LaTeX source (for printing) → docs/nerdverse-companion.tex"
echo
echo "Tip: Add this script to your workflow or run it before committing doc changes."

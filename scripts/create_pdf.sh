#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
INPUT_FILE="$REPO_ROOT/MANUSCRIPT.md"
OUTPUT_FILE="$REPO_ROOT/MANUSCRIPT.pdf"
COVER_FILE="$REPO_ROOT/cover.png"
BUILD_DIR="$(mktemp -d "$REPO_ROOT/.pdf-build.XXXXXX")"
NORMALIZED_MD="$BUILD_DIR/manuscript.normalized.md"
METADATA_FILE="$BUILD_DIR/metadata.yaml"
HEADER_FILE="$BUILD_DIR/header.tex"
BEFORE_BODY_FILE="$BUILD_DIR/before-body.tex"

cleanup() {
  rm -rf "$BUILD_DIR"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

trap cleanup EXIT

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Manuscript not found: $INPUT_FILE" >&2
  exit 1
fi

if [[ ! -f "$COVER_FILE" ]]; then
  echo "Cover image not found: $COVER_FILE" >&2
  exit 1
fi

require_command pandoc
require_command pdflatex

title="$(awk 'NR == 1 && /^# / { sub(/^# /, ""); print; exit }' "$INPUT_FILE")"
author="$(awk 'NR <= 6 && /^A Novel by / { sub(/^A Novel by /, ""); print; exit }' "$INPUT_FILE")"

if [[ -z "$title" ]]; then
  echo "Could not determine manuscript title from $INPUT_FILE" >&2
  exit 1
fi

if [[ -z "$author" ]]; then
  author="Joshua Szepietowski"
fi

# Drop the title block so acts and chapters can become the PDF's visible structure.
awk '
  NR == 1 && /^# / {
    skip_leading_blank = 1
    next
  }
  skip_leading_blank && /^A Novel by / {
    next
  }
  skip_leading_blank && $0 == "" {
    next
  }
  {
    skip_leading_blank = 0
    print
  }
' "$INPUT_FILE" > "$NORMALIZED_MD"

cat > "$METADATA_FILE" <<'EOF'
---
documentclass: book
classoption:
  - oneside
  - openany
fontsize: 11pt
date: ""
geometry:
  - paperwidth=6in
  - paperheight=9in
  - inner=0.8in
  - outer=0.7in
  - top=0.9in
  - bottom=0.85in
---
EOF

cat > "$HEADER_FILE" <<'EOF'
\usepackage{graphicx}
\usepackage{mathpazo}
\usepackage{eso-pic}
\usepackage{titlesec}
\usepackage{xcolor}
\usepackage{setspace}
\usepackage{fancyhdr}
\usepackage{emptypage}

\definecolor{manuscriptink}{HTML}{231F1B}
\definecolor{manuscriptaccent}{HTML}{8B6B4A}
\definecolor{manuscriptmuted}{HTML}{6F655E}

\makeatletter
\@ifpackageloaded{microtype}{\microtypesetup{protrusion=true,expansion=true}}{}
\makeatother

\AtBeginDocument{\color{manuscriptink}}
\setstretch{1.08}
\setlength{\parindent}{1.25em}
\setlength{\parskip}{0.35em}
\setlength{\headheight}{14pt}
\raggedbottom
\renewcommand{\maketitle}{}

\fancypagestyle{plain}{%
  \fancyhf{}
  \fancyfoot[C]{\color{manuscriptmuted}\thepage}
  \renewcommand{\headrulewidth}{0pt}
}
\pagestyle{plain}

\titleformat{\part}[display]
  {\thispagestyle{empty}\centering\normalfont\Huge\scshape\color{manuscriptaccent}}
  {}
  {0pt}
  {\vspace*{0.18\textheight}}
  [\vspace{1.5em}\color{manuscriptmuted}\rule{0.35\textwidth}{0.6pt}\vspace{0.05\textheight}]

\titleformat{\chapter}[display]
  {\normalfont\huge\bfseries\color{manuscriptink}}
  {}
  {0pt}
  {\filright}
  [\vspace{1ex}\titlerule]

\titlespacing*{\chapter}{0pt}{0pt}{2.2em}
EOF

cat > "$BEFORE_BODY_FILE" <<EOF
\\newgeometry{margin=0pt}
\\thispagestyle{empty}
\\AddToShipoutPictureBG*{%
  \\AtPageLowerLeft{%
    \\includegraphics[width=\\paperwidth,height=\\paperheight]{$COVER_FILE}%
  }%
}
\\null
\\clearpage
\\restoregeometry
\\setcounter{page}{1}
EOF

pandoc "$NORMALIZED_MD" \
  --standalone \
  --from=gfm \
  --resource-path="$REPO_ROOT" \
  --metadata-file="$METADATA_FILE" \
  --metadata="title:$title" \
  --metadata="author:$author" \
  --shift-heading-level-by=-1 \
  --top-level-division=part \
  --include-before-body="$BEFORE_BODY_FILE" \
  --include-in-header="$HEADER_FILE" \
  --pdf-engine=pdflatex \
  --pdf-engine-opt=-interaction=nonstopmode \
  --pdf-engine-opt=-halt-on-error \
  -o "$OUTPUT_FILE"

echo "Wrote $OUTPUT_FILE"
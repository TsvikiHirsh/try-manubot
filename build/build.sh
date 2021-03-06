set -o errexit

# Set timezone used by Python for setting the manuscript's date
export TZ=Etc/UTC
# Default Python to read/write text files using UTF-8 encoding
export LC_ALL=en_US.UTF-8

# Generate reference information
echo "Retrieving and processing reference metadata"
manubot process \
  --content-directory=content \
  --output-directory=output \
  --cache-directory=ci/cache \
  --log-level=INFO

# pandoc settings
CSL_PATH=build/assets/style.csl
BIBLIOGRAPHY_PATH=output/references.json
INPUT_PATH=output/manuscript.md

# Make output directory
mkdir -p output

# Create HTML output
# http://pandoc.org/MANUAL.html
echo "Exporting HTML manuscript"
pandoc --verbose \
  --from=markdown \
  --to=html5 \
  --filter=pandoc-fignos \
  --filter=pandoc-eqnos \
  --filter=pandoc-tablenos \
  --bibliography=$BIBLIOGRAPHY_PATH \
  --csl=$CSL_PATH \
  --metadata link-citations=true \
  --include-after-body=build/themes/default.html \
  --include-after-body=build/plugins/table-scroll.html \
  --include-after-body=build/plugins/anchors.html \
  --include-after-body=build/plugins/accordion.html \
  --include-after-body=build/plugins/tooltips.html \
  --include-after-body=build/plugins/jump-to-first.html \
  --include-after-body=build/plugins/link-highlight.html \
  --include-after-body=build/plugins/table-of-contents.html \
  --include-after-body=build/plugins/lightbox.html \
  --mathjax \
  --variable math="" \
  --include-after-body=build/plugins/math.html \
  --include-after-body=build/plugins/hypothesis.html \
  --include-after-body=build/plugins/analytics.html \
  --output=output/manuscript.html \
  $INPUT_PATH

# Return null if docker command is missing, otherwise return path to docker
DOCKER_EXISTS=`command -v docker`

# Create PDF output (unless BUILD_PDF environment variable equals "false")
if [ "$BUILD_PDF" != "false" ] && [ -z "$DOCKER_EXISTS" ]; then
  echo "Exporting PDF manuscript using WeasyPrint"
  if [ -L images ]; then rm images; fi  # if images is a symlink, remove it
  ln -s content/images
  pandoc \
    --from=markdown \
    --to=html5 \
    --pdf-engine=weasyprint \
    --pdf-engine-opt=--presentational-hints \
    --filter=pandoc-fignos \
    --filter=pandoc-eqnos \
    --filter=pandoc-tablenos \
    --bibliography=$BIBLIOGRAPHY_PATH \
    --csl=$CSL_PATH \
    --metadata link-citations=true \
    --webtex=https://latex.codecogs.com/svg.latex? \
    --include-after-body=build/themes/default.html \
    --output=output/manuscript.pdf \
    $INPUT_PATH
  rm images
fi

# Create PDF output (unless BUILD_PDF environment variable equals "false")
if [ "$BUILD_PDF" != "false" ] && [ -n "$DOCKER_EXISTS" ]; then
  echo "Exporting PDF manuscript using Docker + Athena"
  if [ -d output/images ]; then rm -rf output/images; fi  # if images is a directory, remove it
  cp -R -L content/images output/
  docker run \
    --rm \
    --shm-size=1g \
    --volume=`pwd`/output:/converted/ \
    --security-opt=seccomp:unconfined \
    arachnysdocker/athenapdf:2.16.0 \
    athenapdf \
    --delay=2000 \
    manuscript.html manuscript.pdf
  rm -rf output/images
fi

# Create DOCX output (if BUILD_DOCX environment variable equals "true")
if [ "$BUILD_DOCX" = "true" ]; then
  echo "Exporting Word Docx manuscript"
  pandoc --verbose \
    --from=markdown \
    --to=docx \
    --filter=pandoc-fignos \
    --filter=pandoc-eqnos \
    --filter=pandoc-tablenos \
    --bibliography=$BIBLIOGRAPHY_PATH \
    --csl=$CSL_PATH \
    --metadata link-citations=true \
    --reference-doc=build/themes/default.docx \
    --resource-path=.:content \
    --output=output/manuscript.docx \
    $INPUT_PATH
fi

echo "Build complete"

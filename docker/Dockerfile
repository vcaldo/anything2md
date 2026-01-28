# Custom marker image with WeasyPrint dependencies for PPTX conversion
# Extends xiaoyao9184/marker:latest with Pango system libraries

FROM xiaoyao9184/marker:latest

# Install WeasyPrint dependencies (Pango libraries)
# These are required for PPTX conversion support
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    && rm -rf /var/lib/apt/lists/*

LABEL maintainer="anything2md"
LABEL description="Marker image with WeasyPrint dependencies for full document format support"

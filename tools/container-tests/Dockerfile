FROM python:3.12-slim-bookworm

# The engine is supplied read-only from the operator's verified local install.
# No engine download, export template or third-party asset is added to the image.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libx11-6 libxcursor1 libxinerama1 libgl1 libasound2 libpulse0 \
    libxrandr2 libxi6 libfontconfig1 && rm -rf /var/lib/apt/lists/*
RUN ln -s /opt/godot /usr/local/bin/godot
COPY tools/container-tests/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["bash", "/entrypoint.sh"]

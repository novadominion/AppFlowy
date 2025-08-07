#================
# BUILDER STAGE
#================

FROM archlinux/archlinux:base-devel as builder

# Set up build user
RUN pacman -Syyu --noconfirm && \
    pacman -S --needed --noconfirm sudo && \
    useradd --system --create-home makepkg && \
    echo "makepkg ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

USER makepkg
WORKDIR /home/makepkg

# Set environment variables
ENV PATH="/home/makepkg/.pub-cache/bin:/home/makepkg/flutter/bin:/home/makepkg/flutter/bin/cache/dart-sdk/bin:/home/makepkg/.cargo/bin:${PATH}"

# Install build dependencies
RUN sudo pacman -S --needed --noconfirm \
    curl base-devel openssl clang cmake ninja pkg-config xdg-user-dirs \
    git tar gtk3 jemalloc libkeybinder3 sqlite rsync libnotify rocksdb zstd mpv

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    source ~/.cargo/env && \
    rustup toolchain install 1.81 && \
    rustup default 1.81

# Install Flutter
RUN xdg-user-dirs-update && \
    curl -sSfL --output flutter.tar.xz \
    https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.27.4-stable.tar.xz && \
    tar -xf flutter.tar.xz && \
    rm flutter.tar.xz && \
    flutter config --enable-linux-desktop && \
    flutter doctor && \
    dart pub global activate protoc_plugin 21.1.2

# Install cargo tools
RUN sudo ln -s /usr/bin/sha1sum /usr/bin/shasum && \
    source ~/.cargo/env && \
    cargo install cargo-make --version 0.37.18 --locked && \
    cargo install cargo-binstall --version 1.10.17 --locked && \
    cargo binstall duckscript_cli --locked -y

# Copy application source
COPY --chown=makepkg:makepkg . /appflowy
WORKDIR /appflowy

# Build AppFlowy
RUN cd frontend && \
    source ~/.cargo/env && \
    cargo make appflowy-flutter-deps-tools && \
    cargo make flutter_clean && \
    OPENSSL_STATIC=1 ZSTD_SYS_USE_PKG_CONFIG=1 ROCKSDB_LIB_DIR="/usr/lib/" \
    cargo make -p production-linux-x86_64 appflowy-linux

#================
# RUNTIME STAGE
#================

FROM archlinux/archlinux:latest

# Install runtime dependencies
RUN pacman -Syyu --noconfirm && \
    pacman -S --needed --noconfirm \
    xdg-user-dirs gtk3 libkeybinder3 libnotify rocksdb \
    xvfb x11vnc fluxbox novnc websockify && \
    pacman -Scc --noconfirm

# Set up appflowy user
RUN useradd --create-home --uid 1000 --gid 100 appflowy
USER appflowy
WORKDIR /home/appflowy

# Copy built application
COPY --from=builder --chown=appflowy:users /appflowy/frontend/appflowy_flutter/build/linux/x64/release/bundle ./appflowy

# Set up X11 virtual display
ENV DISPLAY=:99
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080

# Create startup script
USER root
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Start X virtual framebuffer\n\
Xvfb :99 -screen 0 1280x720x24 &\n\
sleep 2\n\
\n\
# Start window manager\n\
DISPLAY=:99 fluxbox &\n\
sleep 2\n\
\n\
# Start VNC server\n\
x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -ncache 10 -forever &\n\
\n\
# Start noVNC web server\n\
websockify --web=/usr/share/novnc 0.0.0.0:6080 localhost:5900 &\n\
\n\
# Start AppFlowy\n\
cd /home/appflowy/appflowy\n\
DISPLAY=:99 ./AppFlowy &\n\
\n\
# Keep container running\n\
wait' > /start.sh && \
    chmod +x /start.sh

# Expose ports
EXPOSE 6080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1

# Run the startup script
CMD ["/start.sh"]
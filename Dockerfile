# =============================================================================
# Soccer Stars Analyzer — p4a Build Image
# =============================================================================
FROM ubuntu:22.04

# ── Non-interactive apt ──────────────────────────────────────────────────────
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ── Android SDK/NDK paths (frozen) ──────────────────────────────────────────
ENV ANDROID_HOME=/opt/android/sdk
ENV ANDROID_SDK_ROOT=/opt/android/sdk
ENV ANDROIDSDK=/opt/android/sdk
ENV ANDROIDNDK=/opt/android/sdk/ndk/25.1.8937393
ENV ANDROID_NDK_HOME=/opt/android/sdk/ndk/25.1.8937393
ENV ANDROIDAPI=33
ENV ANDROIDMINAPI=26
ENV ANDROIDNDKAPI=26

ENV PATH="/usr/local/bin:/opt/android/sdk/build-tools/33.0.0:/opt/android/sdk/platform-tools:/opt/android/sdk/cmdline-tools/latest/bin:${PATH}"

# ── 1. System packages ───────────────────────────────────────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        wget curl ca-certificates \
        git zip unzip \
        openjdk-17-jdk \
        python3.11 python3.11-dev python3-pip \
        autoconf automake libtool \
        pkg-config \
        zlib1g-dev \
        libncurses6 libncursesw6 \
        libssl-dev libffi-dev \
        libsqlite3-dev \
        build-essential ccache cmake ninja-build gettext && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 2. Pin python3 / pip to 3.11 ────────────────────────────────────────────
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python  python  /usr/bin/python3.11 1 && \
    python3 -m pip install --upgrade pip wheel setuptools

# ── 3. Install python-for-android & Cython ───────────────────────────────────
# تم استبدال buildozer بـ python-for-android مباشرة
RUN pip install "cython==3.0.10" "python-for-android"

# ── 4. Android command-line tools ───────────────────────────────────────────
RUN mkdir -p "$ANDROID_HOME/cmdline-tools" && \
    wget -q \
      "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" \
      -O /tmp/ct.zip && \
    unzip -q /tmp/ct.zip -d /tmp/ct_unpack && \
    mv /tmp/ct_unpack/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest" && \
    rm -f /tmp/ct.zip

# ── 5. Accept all SDK licenses ──────────────────────────────────────────────
RUN yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses 2>/dev/null || true && \
    yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses 2>/dev/null || true

# ── 6. Install SDK components ───────────────────────────────────────────────
RUN "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
      "platform-tools" \
      "build-tools;33.0.0" \
      "platforms;android-33" \
      "ndk;25.1.8937393"

# ── 7. sdkmanager interceptor ───────────────────────────────────────────────
RUN REAL="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" && \
    cat > /usr/local/bin/sdkmanager << WRAPPER
#!/usr/bin/env bash
REAL_BIN="$REAL"
ARGS=()
for arg in "\$@"; do
  case "\$arg" in
    build-tools\;37*) ARGS+=("build-tools;33.0.0"); echo "[interceptor] rewrote \$arg → build-tools;33.0.0" ;;
    build-tools\;36*) ARGS+=("build-tools;33.0.0"); echo "[interceptor] rewrote \$arg → build-tools;33.0.0" ;;
    --update)         echo "[interceptor] dropped --update" ;;
    *)                ARGS+=("\$arg") ;;
  esac
done
exec "\$REAL_BIN" "\${ARGS[@]}"
WRAPPER
RUN chmod +x /usr/local/bin/sdkmanager

# ── 8. Final verification ───────────────────────────────────────────────────
RUN echo "=== p4a Build image verification ===" && \
    python --version && \
    p4a --version && \
    echo "=== Image ready ==="

# ── 9. Install project requirements ─────────────────────────────────────────
COPY requirements.txt /workspace/
RUN pip install -r /workspace/requirements.txt

WORKDIR /workspace

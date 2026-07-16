# CleanCity build environment — Android + Web only.
#
# iOS builds require macOS/Xcode and cannot run in a Linux container; the
# GitHub Actions "build" job still uses a macOS runner for that target.
#
# Usage:
#   docker build -t cleancity-build .
#   docker run --rm -v "$(pwd)/build:/app/build" cleancity-build \
#     flutter build apk --release --dart-define-from-file=env/dev.json
#   docker run --rm -v "$(pwd)/build:/app/build" cleancity-build \
#     flutter build web --release --dart-define-from-file=env/dev.json
#   docker run --rm cleancity-build flutter analyze --no-fatal-infos

FROM eclipse-temurin:17-jdk-jammy

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl unzip xz-utils zip git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# --- Android SDK: cmdline-tools, platform-tools, one platform + build-tools ---
RUN mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" \
    && curl -sSLo /tmp/cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    && unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_SDK_ROOT}/cmdline-tools" \
    && mv "${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools" "${ANDROID_SDK_ROOT}/cmdline-tools/latest" \
    && rm /tmp/cmdline-tools.zip

RUN yes | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --licenses > /dev/null 2>&1 \
    && sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" \
       "platform-tools" "platforms;android-35" "build-tools;35.0.0" > /dev/null

# --- Flutter SDK (stable channel, same as CI's subosito/flutter-action) ---
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_HOME}" \
    && flutter config --no-analytics \
    && flutter precache --android --web \
    && yes | flutter doctor --android-licenses > /dev/null 2>&1 || true

WORKDIR /app

# Cache pub packages in their own layer, only invalidated when pubspec changes.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

CMD ["flutter", "build", "apk", "--release"]

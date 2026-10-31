# ADS Kotlin lab sandbox image (SPEC, not yet built; paiml/catalogue#707). Modelled on ads-julia-render:
# base by digest, toolchain from official archives with verified sha256, offline dependency bake, run with --network none.
# BUILD CONTEXT: a clean export, never the working tree:  git archive <sha> kotlin/lab/ols-from-scratch datasets/penguins | tar -x -C ctx
#                 docker build -f ctx/kotlin/lab/ols-from-scratch/image/Dockerfile ctx
# base: debian:bookworm-slim, same digest the Julia image pins (recorded 2026-10-27)
FROM debian@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/*
# JDK 25: Temurin 25.0.5+8 x64 linux, official adoptium/temurin25-binaries asset; sha256 equals the checksum api.adoptium.net lists.
ARG JDK_URL=https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5%2B8/OpenJDK25U-jdk_x64_linux_hotspot_25.0.5_8.tar.gz
ARG JDK_SHA=68982529869257d0ee6b824ec5aa270ff8b118bb438670da0b97ebdab178d7fb
RUN curl -fsSL -o /tmp/jdk.tgz "$JDK_URL" && echo "$JDK_SHA  /tmp/jdk.tgz" | sha256sum -c - \
 && mkdir /opt/jdk && tar -xzf /tmp/jdk.tgz -C /opt/jdk --strip-components=1 && rm /tmp/jdk.tgz
ENV JAVA_HOME=/opt/jdk PATH=/opt/jdk/bin:$PATH GRADLE_USER_HOME=/opt/gradle-home
RUN java -version 2>&1 | grep -F '25.0.5+8'
# Gradle 9.8.2: sha from gradle-wrapper.properties AND from services.gradle.org/distributions/gradle-9.8.2-bin.zip.sha256 (both must agree)
ARG GRADLE_SHA=21bd5da2de49b642904077f38c0efdc7778e92b3ed0889392dca61b97e389607
RUN curl -fsSL -o /tmp/g.zip https://services.gradle.org/distributions/gradle-9.8.2-bin.zip \
 && test "$(curl -fsSL https://services.gradle.org/distributions/gradle-9.8.2-bin.zip.sha256)" = "$GRADLE_SHA" \
 && echo "$GRADLE_SHA  /tmp/g.zip" | sha256sum -c - \
 && unzip -q /tmp/g.zip -d /opt && ln -s /opt/gradle-9.8.2/bin/gradle /usr/local/bin/gradle && rm /tmp/g.zip
# Lab at the same relative layout the build expects (datasets three levels up from the lab dir).
COPY kotlin/lab/ols-from-scratch/ /w/kotlin/lab/ols-from-scratch/
COPY datasets/penguins/ /w/datasets/penguins/
WORKDIR /w/kotlin/lab/ols-from-scratch
# Bake Kotlin plugin 2.4.21 + JUnit 6.1.3 (network at BUILD only). No failure is swallowed:
# solution must pass; starter must exit 1 (exit 0 or any other code fails the build); then prove the cache is complete offline.
RUN gradle --no-daemon -Pvariant=solution test
RUN set +e; gradle --no-daemon -Pvariant=starter test; rc=$?; test "$rc" = 1
RUN gradle --no-daemon --offline -Pvariant=solution test
# Proof inside the image, network none: bash proof.sh asserts the JUnit XML (8 run; the 7 named failures on starter; 8/8 on solution).

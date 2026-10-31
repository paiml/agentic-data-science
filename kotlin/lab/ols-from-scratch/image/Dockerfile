# ADS Kotlin lab sandbox image (SPEC, not yet built; paiml/catalogue#707). Modelled on the ads-julia-render image:
# base by digest, toolchain from the official tarball with a verified sha256, offline dependency bake, run with --network none.
# base: debian:bookworm-slim, same digest the Julia image pins (recorded 2026-10-27)
FROM debian@sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/*
# JDK 25: Temurin 25.0.5 x64 linux. The sha256 below is the one measured on the tarball used for the recorded runs.
ARG JDK_URL=https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.5%2B8/OpenJDK25U-jdk_x64_linux_hotspot_25.0.5_8.tar.gz
ARG JDK_SHA=68982529869257d0ee6b824ec5aa270ff8b118bb438670da0b97ebdab178d7fb
RUN curl -fsSL -o /tmp/jdk.tgz "$JDK_URL" && echo "$JDK_SHA  /tmp/jdk.tgz" | sha256sum -c - \
 && mkdir /opt/jdk && tar -xzf /tmp/jdk.tgz -C /opt/jdk --strip-components=1 && rm /tmp/jdk.tgz
ENV JAVA_HOME=/opt/jdk PATH=/opt/jdk/bin:$PATH GRADLE_USER_HOME=/opt/gradle-home
# Gradle 9.8.2: distributionSha256Sum from gradle-wrapper.properties
ARG GRADLE_SHA=21bd5da2de49b642904077f38c0efdc7778e92b3ed0889392dca61b97e389607
RUN curl -fsSL -o /tmp/g.zip https://services.gradle.org/distributions/gradle-9.8.2-bin.zip && echo "$GRADLE_SHA  /tmp/g.zip" | sha256sum -c - \
 && unzip -q /tmp/g.zip -d /opt && ln -s /opt/gradle-9.8.2/bin/gradle /usr/local/bin/gradle && rm /tmp/g.zip && test "$(java -version 2>&1 | head -n1 | grep -c 25)" = 1
# Bake the Kotlin plugin 2.4.21 + JUnit 6.1.3 into the Gradle cache by running the solution suite once (needs network at build only).
COPY . /lab/
WORKDIR /lab
RUN gradle --no-daemon -Pvariant=solution test && gradle --no-daemon -Pvariant=starter test || true
# Run: docker run --rm --network none -v <lab>:/lab ... gradle --offline test -Pvariant=starter|solution
# The datasets path (../../../datasets) must be mounted at /datasets-relative layout; see SPEC.md.

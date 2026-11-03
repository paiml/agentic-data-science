FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NGINX_FILES_PATH=/home/nginx

# Common sdk or packages required to install languages
RUN apt-get update && apt-get install --no-install-recommends -y \
    gpg \
    curl \
    wget \
    lsb-release \
    add-apt-key \
    ca-certificates \
    dumb-init \
    git \
    sudo \
    build-essential \
    ucommon-utils \
    zip \
    unzip \
    openssh-server \
    # Python SDK
    python3 \
    python-dev \
    python3-pip \
    # C and C++ SDK
    valgrind \
    gdb \
    # Ruby SDK
    ruby-full \
    # PHP SDK
    php \ 
    # Code Server
    libarchive-tools \
    locales \
    # Web Server
    nginx \
    supervisor \
    && apt-get clean

# Node SDK (PATCH vs upstream: nodesource's setup_14.x repo key is dead, so Node 14 comes from the official tarball)
RUN curl -fsSL https://nodejs.org/dist/v14.21.3/node-v14.21.3-linux-x64.tar.xz | tar -xJ -C /usr/local --strip-components=1 \
    && npm install -g typescript

# Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install --no-install-recommends yarn

# Golang SDK
ENV GO_VERSION="1.17.13"
RUN curl -sL https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz | tar -xz -C /usr/local

# Make Python3 default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Python SDK
RUN python3 -m pip install --upgrade setuptools \
    && python3 -m pip install wheel pylint requests

# PATCH vs upstream: Java, Scala, sbt, mono, Rust and Chrome removed (a Lean lab needs none; image must fit the runner disk and the Lab size cap).

# Code-Server
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8
ENV DISABLE_TELEMETRY true

# actual install of code server
ENV CODE_VERSION="3.12.0"
RUN curl -fsSL https://code-server.dev/install.sh | bash /dev/stdin --version $CODE_VERSION

# Set up User
RUN groupadd -r coder \
    && useradd -m -r coder -g coder -s /bin/bash \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd
USER coder

# Set up User Go Environment
RUN mkdir /home/coder/go
ENV GOPATH "/home/coder/go"
ENV PATH "${PATH}:/usr/local/go/bin:/home/coder/go/bin"

# Lean 4 (core Lean, no Mathlib): elan installed at build time as `coder`. The toolchain is NOT written here: CI and
# default below equals labs/e-final/lean-toolchain (tests/image-pin.sh), because Coursera builds with ZERO build args; an empty value fails the build. The installer is
# sha256-verified against elan-init.sh.sha256 (no unchecked curl | sh).
# Container-is-the-sandbox: the lab grader compiles learner code under bwrap when it can; Coursera labs are unprivileged (no user
# namespaces), so the image sets GRADER_SANDBOX=container plus a root-owned marker file, and tests/run.sh honours that pair only.
ENV GRADER_SANDBOX=container
RUN echo "container is the sandbox" | sudo tee /etc/ads-lab-container-sandbox >/dev/null && sudo chmod 644 /etc/ads-lab-container-sandbox

ARG LEAN_TOOLCHAIN=leanprover/lean4:v4.35.0
COPY elan-init.sh.sha256 /tmp/elan-init.sh.sha256
ENV ELAN_HOME "/home/coder/.elan"
ENV PATH "${PATH}:/home/coder/.elan/bin"
RUN test -n "${LEAN_TOOLCHAIN}" \
    && curl -fsSL https://elan.lean-lang.org/elan-init.sh -o /tmp/elan-init.sh \
    && echo "$(cat /tmp/elan-init.sh.sha256)  /tmp/elan-init.sh" | sha256sum -c - \
    && sh /tmp/elan-init.sh -y --no-modify-path --default-toolchain "${LEAN_TOOLCHAIN}" \
    && "${ELAN_HOME}/bin/elan" toolchain install "${LEAN_TOOLCHAIN}" \
    && lean --version \
    && rm /tmp/elan-init.sh

# Set up User Visual Studio Code Extensions
ENV VSCODE_USER "/home/coder/.local/share/code-server/User"
ENV VSCODE_EXTENSIONS "/home/coder/.local/share/code-server/extensions"

RUN mkdir -p ${VSCODE_USER}

# PATCH vs upstream: the Go tools, the C/C++ vsix and the marketplace extension installs are removed (a Lean lab needs none; upstream steps fail at HEAD).

# Set up environment variables required for Scala to work (without cosmetic errors)
RUN echo 'export JAVA_HOME=$(readlink -f /usr/bin/javac | sed "s:/bin/javac::")' >> /home/coder/.bashrc
RUN echo "export TERM=xterm" >> /home/coder/.bashrc

COPY extensions/ /tmp/

# Set up C# Extension (disabled since it's always trying to install packages)
#RUN code-server --install-extension ms-dotnettools.csharp --extensions-dir=$VSCODE_EXTENSIONS

# code-server v3.12.0 does not use the open VSX marketplace by default. This fixes that
ENV SERVICE_URL=https://open-vsx.org/vscode/gallery 
ENV ITEM_URL=https://open-vsx.org/vscode/item


# Set up coursera launch button extension
RUN mkdir -p $VSCODE_EXTENSIONS/coursera-launch-button \
    && bsdtar --strip-components=1 -xf /tmp/coursera-launch-button-0.0.1.vsix -C $VSCODE_EXTENSIONS/coursera-launch-button extension

# This fixes the health check bug
COPY index.html /home/travis/build/codercom/code-server/packages/server/build/web/


ENV SHELL /bin/bash

USER root

# Launch button
COPY --chown=coder:coder coursera-launch-button/ $VSCODE_USER/coursera/
COPY --chown=coder:coder launchButtonSettings.json /tmp/launchButtonSettings.json
RUN mkdir -p /home/coder/coursera

# Turns off the welcome page
COPY --chown=coder:coder settings.json $VSCODE_USER

# Makes terminal open bash by default
COPY start.sh /usr/local/bin/
COPY config.yaml /tmp/config/code-server/
RUN chmod 755 /usr/local/bin/start.sh

# Put coursera submission scripts in python lib
COPY coursera-submission /tmp/coursera
RUN for d in $(ls /usr/lib | grep "^python*") ; do cp -r /tmp/coursera /usr/lib/$d; done

# Web server
VOLUME ["/etc/nginx/sites-enabled", "/etc/nginx/certs", "/etc/nginx/conf.d", "/var/log/nginx", "/var/www/html"]
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create directory for nginx-related files
RUN mkdir -p $NGINX_FILES_PATH
COPY nginx-files/ /tmp/nginx-files/

USER coder

# Create supervisord log files
RUN mkdir -p /var/log/supervisor
RUN sudo touch /var/log/supervisor/supervisord.log \
  && sudo touch /var/log/supervisor/code-server-stdout.log \
  && sudo touch /var/log/supervisor/code-server-stderr.log
RUN sudo chmod 766 /var/log/supervisor/*

# Setup User Workspace
RUN mkdir -p /home/coder/project

# Copy the default .hidden file
COPY .hidden /tmp/.hidden

# Create a template reverse-proxy for partners to modify if they wish
COPY nginx-files/reverse-proxy.conf /etc/nginx/sites-enabled/reverse-proxy.conf.template

# Setting up directory for global npm packages (installed via easy docker config)
RUN sudo mkdir -p /home/npm-global
WORKDIR /home/npm-global
RUN sudo npm init -y

# Set global npm prefix (packages installed here still get symlinked to the project directory)
# under /home/coder/project, so unfortunately they will still be under mount point
RUN sudo npm config set prefix /home/npm-global --global
RUN sudo chown coder:coder /home/npm-global

WORKDIR /home/coder/project

ENTRYPOINT ["dumb-init", "--"]

USER root
CMD ["start.sh"]

# This will generally always be needed for React apps
RUN npm install react-scripts --global \
    # Needed for reverse-proxy easy config
    && npm install nginx-conf --global 
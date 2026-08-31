FROM ubuntu:22.04

ARG SONAR_SCANNER_VERSION=5.0.1.3006
ARG JENKINS_AGENT_HOME=/home/jenkins
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    SONAR_SCANNER_HOME=/opt/sonar-scanner \
    PATH="/opt/sonar-scanner/bin:${PATH}"

# --- Base packages + Java (required by sonar-scanner) + tools ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless \
        curl \
        wget \
        unzip \
        git \
        ca-certificates \
        software-properties-common \
        gnupg \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
        python3.11 \
        python3.11-venv \
        python3.11-distutils \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Install Sonar Scanner CLI ---
RUN curl -sSLo /tmp/sonar-scanner.zip \
        "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux.zip" \
    && unzip -q /tmp/sonar-scanner.zip -d /opt \
    && mv /opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux ${SONAR_SCANNER_HOME} \
    && rm /tmp/sonar-scanner.zip \
    && chmod +x ${SONAR_SCANNER_HOME}/bin/sonar-scanner

# --- Non-root jenkins user (Kubernetes pod agents run unprivileged) ---
RUN groupadd -g ${GID} jenkins \
    && useradd -u ${UID} -g ${GID} -m -d ${JENKINS_AGENT_HOME} -s /bin/bash jenkins

RUN mkdir -p /home/jenkins/agent && chown -R jenkins:jenkins /home/jenkins

USER jenkins
WORKDIR /home/jenkins/agent

# Sanity check versions at build time
RUN python3 --version && sonar-scanner --version || true

# Kubernetes plugin normally overrides command/args from the pod template
# (e.g. command: ["cat"], args: ["-c", "while true; do sleep 30; done"], tty: true)
CMD ["/bin/bash"]
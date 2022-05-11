FROM gitpod/workspace-full
USER root

RUN mkdir $HOME/bin
RUN npm install -g @bazel/bazelisk
RUN npm install -g @bazel/ibazel

ARG CONFTEST_URL="https://github.com/open-policy-agent/conftest/releases/download/v0.32.0/conftest_0.32.0_linux_amd64.deb"
RUN curl -sSL "${CONFTEST_URL}" -o conftest.deb \
    && dpkg -i conftest.deb \
    && rm conftest.deb

ARG TERRAFORM_URL="https://releases.hashicorp.com/terraform/1.1.9/terraform_1.1.9_linux_amd64.zip"
RUN curl -sSL "${TERRAFORM_URL}" -o terraform.zip \
    && unzip terraform.zip \
    && rm terraform.zip \
    && chmod +x terraform \
    && mv terraform /usr/local/bin/terraform

ARG BAZEL_BUILDTOOLS_URL="https://github.com/bazelbuild/buildtools/releases/download/"
RUN curl -sSL "${BAZEL_BUILDTOOLS_URL}/5.1.0/buildozer" > /usr/local/bin/buildozer && \
    curl -sSL "${BAZEL_BUILDTOOLS_URL}/5.1.0/buildifier" >  /usr/local/bin/buildifier && \
    chmod +x /usr/local/bin/buildozer && \
    chmod +x /usr/local/bin/buildifier 

USER gitpod
FROM mcr.microsoft.com/powershell:lts-ubuntu-18.04

LABEL maintainer="Xorima"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="xorima/github-label-manager"
LABEL org.label-schema.description="A Label Manager system for Github Repositories"
LABEL org.label-schema.url="https://github.com/Xorima/github-label-manager"
LABEL org.label-schema.vcs-url="https://github.com/Xorima/github-label-manager"

RUN apt-get update && apt-get install -y git
COPY app /app

ENTRYPOINT ["pwsh", "-file", "app/entrypoint.ps1"]
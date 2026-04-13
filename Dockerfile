FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev \
    default-jdk \
    git curl make \
    nodejs npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN bash -c "cd /app/daikon-5.8.6 && \
    export DAIKONDIR=\$(pwd) && \
    source scripts/daikon.bashrc && \
    make rebuild-everything"

WORKDIR /app/invcon/nodejs
RUN npm install

WORKDIR /app
RUN pip3 install --no-cache-dir \
        slither-analyzer \
        PySocks \
        lxml \
    && pip3 install --no-cache-dir -e .

ENV DAIKONDIR=/app/daikon-5.8.6
ENV PATH="${DAIKONDIR}/scripts:${PATH}"

ENTRYPOINT ["invcon"]
CMD ["--help"]

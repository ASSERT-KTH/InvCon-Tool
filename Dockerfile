FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev \
    default-jdk \
    git curl nodejs npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN cd /app/invcon/nodejs && npm install \
    && pip3 install --no-cache-dir \
        slither-analyzer==0.10.0 \
        PySocks==1.7.1 \
        lxml==4.9.3 \
    && pip3 install --no-cache-dir -e .

ENV DAIKONDIR=/app/daikon-5.8.6
ENV PATH="${DAIKONDIR}/scripts:${PATH}"

ENTRYPOINT ["invcon"]
CMD ["--help"]

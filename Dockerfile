FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev \
    default-jdk \
    git curl nodejs npm \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN cd /app/invcon/nodejs && npm install

WORKDIR /app
COPY . .

RUN sed -i 's/APIKEY_BLOCKCHAIN_ETH = ".*"/APIKEY_BLOCKCHAIN_ETH = os.environ.get("ETHERSCAN_API_KEY", "")/' invcon/crawler/crawler.py

RUN pip3 install --no-cache-dir slither-analyzer PySocks
RUN pip3 install --no-cache-dir -e .

ENV DAIKONDIR=/app/daikon-5.8.6
ENV PATH="${DAIKONDIR}/scripts:${PATH}"

ENTRYPOINT ["invcon"]
CMD ["--help"]

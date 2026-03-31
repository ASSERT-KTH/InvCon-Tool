FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev \
    default-jdk \
    git curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

RUN python3 -c "
import pathlib
p = pathlib.Path('invcon/crawler/crawler.py')
src = p.read_text()
src = src.replace('scraper.proxies = {\"http\": \"socks5://127.0.0.1:20170\", \"https\": \"socks5://127.0.0.1:20170\",\n    \"socks5\": \"socks5://127.0.0.1:20170\"}', 'scraper.proxies = {}')
p.write_text(src)
print('patched:', 'scraper.proxies = {}' in src)
"

RUN pip3 install --no-cache-dir slither-analyzer PySocks
RUN pip3 install --no-cache-dir -e .

ENV DAIKONDIR=/app/daikon-5.8.6
ENV PATH="${DAIKONDIR}/scripts:${PATH}"

ENTRYPOINT ["invcon"]
CMD ["--help"]

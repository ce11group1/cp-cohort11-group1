FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    tini \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY scorer_service.py .
COPY train.py .
COPY drift_check.py .

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["python","scorer_service.py"]

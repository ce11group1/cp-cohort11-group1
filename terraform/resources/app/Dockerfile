# Replaces the yum install commands
FROM python:3.11-slim
WORKDIR /app

# Install dependencies defined in requirements.txt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the simulator script (You must download this from your S3 to local first!)
COPY iot-simulator.py ./app/iot-simulator.py

# Env vars for the app
ENV CERT_DIR=/app/certs
EXPOSE 9100

CMD ["python3", "app/iot-simulator.py"]
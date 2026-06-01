FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY mqtt_exporter.py .

# Run as a non-root user.
RUN useradd --no-create-home --uid 1000 exporter
USER exporter

EXPOSE 9101
ENTRYPOINT ["python", "mqtt_exporter.py"]

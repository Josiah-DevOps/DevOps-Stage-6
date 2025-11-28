# Python log processor
FROM python:3.9-slim

WORKDIR /app

# Copy requirements file
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

CMD ["python", "main.py"]

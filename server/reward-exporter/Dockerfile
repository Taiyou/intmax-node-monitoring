FROM python:3.11-slim

# SSH クライアントをインストール
RUN apt-get update && apt-get install -y openssh-client && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY exporter.py /app/

# SSH ディレクトリを作成
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

EXPOSE 9102

CMD ["python3", "/app/exporter.py"]

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends sqitch libdbd-sqlite3-perl sqlite3 python3 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY infra/sqitch/turso-sqlite /usr/local/bin/turso-sqlite
RUN chmod +x /usr/local/bin/turso-sqlite
COPY infra/sqitch/ /migrations/
WORKDIR /migrations
ENV SQITCH_FULLNAME="GCF Deploy" SQITCH_EMAIL="deploy@greater-change-foundation.invalid"
ENTRYPOINT ["sqitch"]
CMD ["deploy", "--verify"]

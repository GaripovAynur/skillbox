FROM redis:lates
RUN mkdir -p /etc/redis
COPY redis.conf /etc/redis/redis.conf
VOLUME /data
CMD ["redis-server"]
PORT 6379

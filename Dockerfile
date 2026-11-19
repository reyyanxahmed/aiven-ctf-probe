FROM alpine:3.20
RUN apk add --no-cache bash postgresql16-client bind-tools curl python3
COPY probe.sh /probe.sh
RUN chmod +x /probe.sh
EXPOSE 8080
CMD ["/probe.sh"]
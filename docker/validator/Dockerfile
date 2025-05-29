FROM busybox
RUN adduser -D validator
WORKDIR /home/validator
COPY index.cgi web/cgi-bin/index.cgi
RUN chmod +x web/cgi-bin/index.cgi && chown -R validator:validator /home/validator
USER validator
ENTRYPOINT ["sh", "-c"]
CMD ["cd web && exec httpd -f"]
ENV VALIDATE_SCRIPT=/home/validator/validate.sh

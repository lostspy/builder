FROM nyp219/final003
ENV PATH="${PATH}:/app/"
RUN pwd
RUN mkdir -p /app
COPY ./init.sh /app
COPY ./script.sh /app
COPY ./docker-prune.sh /app
COPY ./docker-install.sh /app
RUN chmod u+x /app/*.sh
RUN ls -lrt /app
WORKDIR /app

ENTRYPOINT ["/app/init.sh"]

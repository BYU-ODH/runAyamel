FROM openjdk:8-alpine

RUN apk update && apk add bash

# Copy code into image
COPY yvideo-dict-lookup /yvideo-dict-lookup/

# Copy in the application.conf file
COPY application.conf /yvideo-dict-lookup/conf/

ARG sbt_version
RUN wget -q "https://dl.bintray.com/sbt/native-packages/sbt/0.13.8/sbt-$sbt_version.zip"
RUN unzip -q sbt-$sbt_version.zip
RUN ln -s /sbt/bin/sbt /usr/local/bin/sbt

WORKDIR /yvideo-dict-lookup


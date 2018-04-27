FROM anapsix/alpine-java

RUN apt-get update
RUN apt-get install wget

# Copy code into image
COPY Ayamel /Ayamel/

ARG sbt_version
RUN wget -q "https://dl.bintray.com/sbt/native-packages/sbt/0.13.8/sbt-$sbt_version.zip"
RUN unzip -q sbt-$sbt_version.zip
RUN ln -s /sbt/bin/sbt /usr/local/bin/sbt

WORKDIR /Ayamel


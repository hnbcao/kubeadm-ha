FROM jenkins
MAINTAINER hnbcao@gmail.com
ENV MAVEN_HOME /usr/local/maven
ENV JAVA_HOME  /usr/local/java
ENV CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
ENV PATH ${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${PATH}

COPY apache-maven-3.5.4 /usr/local/maven
USER root
RUN mkdir -p /usr/local/maven/repository  &&  ln -s /usr/java/jdk1.8.0_171 /usr/local/java

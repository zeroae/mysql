FROM percona:5.6

ENV \
    CONSUL_VERSION=0.7.2                                                                        \
    CONSUL_SHA256=aa97f4e5a552d986b2a36d48fdc3a4a909463e7de5f726f3c5a89b8a1be74a58              \
    CONSUL_TEMPLATE_VERSION=0.16.0                                                              \
    CONSUL_TEMPLATE_SHA256=064b0b492bb7ca3663811d297436a4bbf3226de706d2b76adade7021cd22e156     \
    CONTAINERPILOT_VERSION=2.6.0                                                                \
    CONTAINERPILOT_SHA1=c1bcd137fadd26ca2998eec192d04c08f62beb1f                                \
    CONTAINERPILOT=file:///etc/containerpilot.json

# By keeping a lot of discrete steps in a single RUN we can clean up after
# ourselves in the same layer. This is gross but it saves ~100MB in the image
RUN set -ex \
    && export buildDeps='python-dev gcc unzip' \
    && export runDeps='python curl libffi-dev libssl-dev percona-xtrabackup ca-certificates' \
    && apt-get update \
    && apt-get install -y $buildDeps $runDeps --no-install-recommends \
    # \
    # get Python drivers MySQL, Consul, and Manta \
    # \
    && curl -Lvo /tmp/mysql-connector.deb http://dev.mysql.com/get/Downloads/Connector-Python/mysql-connector-python_2.1.3-1debian8.2_all.deb \
    && dpkg -i /tmp/mysql-connector.deb \
    && curl -v -Lo /tmp/mysql-utils.deb http://dev.mysql.com/get/Downloads/MySQLGUITools/mysql-utilities_1.5.6-1debian8_all.deb \
    && dpkg -i /tmp/mysql-utils.deb \
    && curl -Lvo get-pip.py https://bootstrap.pypa.io/get-pip.py \
    && python get-pip.py \
    && pip install \
       python-Consul==0.4.7 \
       manta==2.5.0 \
       mock==2.0.0 \
    # \
    # Add Consul from https://releases.hashicorp.com/consul \
    # \
    && curl --retry 7 --fail -Lvo /tmp/consul.zip \
         "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip" \
    && echo "${CONSUL_SHA256}  /tmp/consul.zip" | sha256sum -c \
    && unzip /tmp/consul.zip -d /usr/local/bin \
    && rm /tmp/consul.zip \
    && mkdir /config \
    # \
    # Add ContainerPilot and set its configuration file path \
    # \
    && curl --retry 7 --fail -Lso /tmp/containerpilot.tar.gz \
         "https://github.com/joyent/containerpilot/releases/download/${CONTAINERPILOT_VERSION}/containerpilot-${CONTAINERPILOT_VERSION}.tar.gz" \
    && echo "${CONTAINERPILOT_SHA1}  /tmp/containerpilot.tar.gz" | sha1sum -c \
    && tar zxf /tmp/containerpilot.tar.gz -C /usr/local/bin \
    && rm /tmp/containerpilot.tar.gz \
    # \
    # clean up to minimize image layer size \
    # \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge -y --auto-remove $buildDeps \
    && rm /tmp/mysql-connector.deb \
    && rm /tmp/mysql-utils.deb \
    && rm /get-pip.py \
    && rm /docker-entrypoint.sh


# configure ContainerPilot and MySQL
COPY etc/* /etc/
COPY bin/manager /usr/local/bin/manager
COPY bin/test.py /usr/local/bin/test.py
COPY bin/manage.py /usr/local/bin/manage.py

# override the parent entrypoint
ENTRYPOINT []

# use --console to get error logs to stderr
CMD [ "containerpilot", \
      "mysqld", \
      "--console", \
      "--log-bin=mysql-bin", \
      "--log_slave_updates=ON", \
      "--gtid-mode=ON", \
      "--enforce-gtid-consistency=ON" \
]

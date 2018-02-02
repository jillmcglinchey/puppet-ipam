FROM puppet/puppet-agent
MAINTAINER peter@pouliot.net
COPY Puppetfile /etc/puppetlabs/code/environments/production/Puppetfile
COPY files/hiera /etc/puppetlabs/code/environments/production/data
RUN \
    apt-get update -y && apt-get install git software-properties-common -y \
    && gem install r10k \
    && cd /etc/puppetlabs/code/environments/production/ \
    && r10k puppetfile install --verbose DEBUG2 \
    && ln -s data/hiera.yaml /etc/puppetlabs/hiera.yaml \
    && cp data/nodes/ipam1.yaml data/nodes/`facter | grep fqdn | awk '{print $3}'| sed -e 's/\"//g'| awk -F. '{print $1}'`.yaml \
    && cp data/nodes/ipam1.yaml data/nodes/`facter | grep fqdn | awk '{print $3}'| sed -e 's/\"//g'`yaml \
    && ls data/nodes && echo $HOSTNAME \
    && mkdir -p /var/lock/named /var/run/named \
    && puppet module list \
    && puppet module list --tree \
    &&  puppet apply --debug --trace --verbose --modulepath=/etc/puppetlabs/code/environments/production/modules /etc/puppetlabs/code/environments/production/modules/ipam/examples/init.pp
RUN /usr/sbin/dhcpd -t
RUN /usr/sbin/named-checkconf
COPY Dockerfile.ubuntu Dockerfile
# Test Slave Build
RUN \
    cd /etc/puppetlabs/code/environments/production/ \
    && cp data/nodes/ipam2.yaml data/nodes/`facter | grep fqdn | awk '{print $3}'| sed -e 's/\"//g'| awk -F. '{print $1}'`.yaml \
    && cp data/nodes/ipam1.yaml data/nodes/`facter | grep fqdn | awk '{print $3}'| sed -e 's/\"//g'`yaml \
    && puppet apply --debug --trace --verbose --modulepath=/etc/puppetlabs/code/environments/production/modules /etc/puppetlabs/code/environments/production/modules/ipam/examples/init.pp
RUN /usr/sbin/dhcpd -t
RUN /usr/sbin/named-checkconf
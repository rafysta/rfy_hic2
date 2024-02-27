# Build dependencies
FROM ubuntu:latest

# Perform root permission-required actions
RUN mkdir /mnt/data_share
RUN apt -y update && apt -y upgrade
RUN apt install sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Add non-root sudoer user
ARG USERNAME=user
ARG GROUPNAME=user
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} ${GROUPNAME} && \
    useradd --create-home -m -s /bin/bash -u ${UID} -g ${GID} ${USERNAME} -G sudo
ENV HOME /home/${USERNAME}

# Switch to run as user
USER ${USERNAME}

# Create default direcotry structure following the published protocol
ENV GENOME_DIR ${HOME}/genome
RUN mkdir ${GENOME_DIR}
RUN mkdir ${GENOME_DIR}/pombe
ENV DIR_DATA_RAW ${HOME}/data_raw
RUN mkdir ${DIR_DATA_RAW}
ENV DIR_DATA ${HOME}/data
RUN mkdir ${DIR_DATA}
ENV DIR_tmporary ${DIR_DATA}/tmp
RUN mkdir -p ${DIR_tmporary}
ENV DIR_LIB ${HOME}/library
RUN mkdir ${DIR_LIB}

# Install apt-managed dependencies
RUN cat /dev/null | sudo -S apt install -y wget
RUN cat /dev/null | sudo -S apt install -y htop
RUN cat /dev/null | sudo -S apt install -y vim
RUN cat /dev/null | sudo -S apt install -y dos2unix
RUN cat /dev/null | sudo -S apt install -y git
RUN cat /dev/null | sudo -S apt install -y sqlite3
RUN cat /dev/null | sudo -S apt install -y fastqc
RUN cat /dev/null | sudo -S apt install -y samtools
RUN cat /dev/null | sudo -S apt install -y bowtie2
RUN cat /dev/null | sudo -S DEBIAN_FRONTEND=noninteractive apt install -y r-base

# Install remaining dependencies
RUN wget --output-document ${DIR_LIB}/sratoolkit.tar.gz http://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-ubuntu64.tar.gz
RUN tar -zxvf ${DIR_LIB}/sratoolkit.tar.gz -C ${DIR_LIB}
RUN mv ${DIR_LIB}/sratoolkit*-ubuntu64 ${DIR_LIB}/sratoolkit
ENV PATH ${DIR_LIB}/sratoolkit/bin:${PATH}

# Copy current repo and set working directory
COPY . ${DIR_LIB}/rfy_hic2
WORKDIR ${DIR_LIB}/rfy_hic2

ENV R_LIBS ${HOME}/local/rlibs
RUN mkdir -p $R_LIBS

# Install required R libraries
RUN Rscript --vanilla ${DIR_LIB}/rfy_hic2/install_libraries.R

# Print out environment variable information
RUN env

ENTRYPOINT [ "bash" ]

# Please check that you have copied relevant input files from the folder shared with the host machine into the respective folders before running rfy_hic2.

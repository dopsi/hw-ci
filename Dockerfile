# mluckydwyer/hw-ci Docker Container
FROM centos:7 as base

LABEL Maintainer="Matthew Dwyer <dwyer@iastate.edu>"
LABEL Description="Hardware Verification CI Docker container"
ENV container docker
#ENV DISPLAY=host.docker.internal:0.0
ENV LIBGL_ALWAYS_INDRIECT=1

# Update Yum Repos & Update All
RUN yum install -y https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.9-1.x86_64.rpm \
    && yum update -y \
    && yum install -y git make epel-release

# Install Python
FROM base as python3
RUN yum -y install gcc gcc-c++ libstdc++-devel \
    &&  yum -y install libgcc.i686 glibc-devel.i686 glibc.i686 zlib-devel.i686 \
        readline-devel.i686 gdbm-devel.i686 openssl-devel.i686 ncurses-devel.i686 \
        tcl-devel.i686 db4-devel.i686 bzip2-devel.i686 libffi-devel.i686 \
    && mkdir /tmp/{Archive,Build} \
    && curl -s -o /tmp/Archive/Python-3.6.14.tgz https://www.python.org/ftp/python/3.6.14/Python-3.6.14.tgz \
    && tar xzvf /tmp/Archive/Python-3.6.14.tgz -C /tmp/Build \
    && rm /tmp/Archive/Python-3.6.14.tgz \
    && mkdir -p /opt/Python-3.6.14
WORKDIR /tmp/Build/Python-3.6.14
RUN CFLAGS=-m32 LDFLAGS=-m32 ./configure --prefix /opt/Python-3.6.14 --enable-shared \
    && LD_RUN_PATH=/opt/Python-3.6.145/lib make -j 8 \
    && make install
ENV PATH="/opt/Python-3.6.14/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/Python-3.6.14/lib:/opt/Python-3.6.14/share:${LD_LIBRARY_PATH}"
ENV CPATH="/opt/Python-3.6.14/include:${CPATH}"
RUN pip3 install --upgrade pip setuptools \
    && pip3 install wheel

# Patch CocoTB-test simulation.py with custom implementation for Modelsim complilation
# RUN rm /opt/Python-3.6.14/lib/python3.6/site-packages/cocotb_test/simulator.py
# COPY resources/simulator.py /opt/Python-3.6.14/lib/python3.6/site-packages/cocotb_test/simulator.py
# EXPOSE 5678

# Install VUnit
FROM python3 as vunit
RUN pip3 install vunit_hdl

# Install Modelsim
FROM vunit as modelsim
RUN yum install -y libiodbc unixODBC ncurses ncurses-libs \
    zeromq-devel libXext alsa-lib libXtst libXft libxml2 libedit libX11 libXi \
    glibc glibc.i686 glibc-devel.i386 libgcc.i686 libstdc++-devel.i686 libstdc++ \
    libstdc++.i686 libXext libXext.i686 libXft libXft.i686 libXrender libXtst
WORKDIR /tmp
RUN curl -s -O https://download.altera.com/akdlm/software/acdsinst/20.1std.1/720/ib_installers/ModelSimSetup-20.1.1.720-linux.run \
    && chmod +x ModelSimSetup-20.1.1.720-linux.run
RUN ./ModelSimSetup-20.1.1.720-linux.run --mode unattended --installdir /opt/intelFPGA/20.1 --accept_eula 1 --modelsim_edition modelsim_ase \
    && rm ModelSimSetup-20.1.1.720-linux.run
ENV PATH="/opt/intelFPGA/20.1/modelsim_ase/bin:${PATH}"


# Install Verilator
FROM modelsim as verilator
RUN yum -y install verilator

# Install GHDL
FROM verilator as ghdl
# RUN yum -y install gtkwave centos-release-scl centos-release-scl && \
#     yum -y install devtoolset-9-gcc fedora-gnat-project-common zlib-devel \
#     scl-utils gcc-gnat
# RUN scl enable devtoolset-9 zsh
# WORKDIR external

RUN yum -y install bzip2 curl flex fontconfig zlib-devel centos-release-scl \
    && yum install -y devtoolset-8 texinfo
RUN mkdir -p /tmp/gnat \
 && curl -sL https://community.download.adacore.com/v1/9682e2e1f2f232ce03fe21d77b14c37a0de5649b?filename=gnat-gpl-2017-x86_64-linux-bin.tar.gz | tar -xz -C /tmp/gnat --strip-components=1 \
 && cd /tmp/gnat \
 && make ins-all prefix="/opt/gnat"
ENV OG_PATH=$PATH
ENV PATH=/opt/gnat/bin:$PATH
# SHELL [ "/usr/bin/scl", "enable", "devtoolset-8" ]

# Compile GCC
# RUN yum -y install bzip2 flex bison
# RUN git clone git://gcc.gnu.org/git/gcc.git gcc
# WORKDIR gcc
# RUN git checkout releases/gcc-11.2.0
# RUN ./contrib/download_prerequisites
# RUN mkdir objdir
# WORKDIR objdir
# RUN ../configure --prefix=$PWD/bin_dir
# RUN make bootstrap-lean -j 4

RUN mkdir ghdl-1.0.0 \
    && curl -sL https://github.com/ghdl/ghdl/archive/refs/tags/v1.0.0.tar.gz | tar -xz -C ./ghdl-1.0.0 --strip-components=1
WORKDIR ghdl-1.0.0
RUN ./configure --prefix=/usr/local \
    && make -j 4 \
    && make install
ENV PATH=$OG_PATH

# Install CocoTb
FROM ghdl as cocotb
RUN pip3 install glob2 coverage matplotlib remote_pdb debugpy teroshdl yowasp-yosys vsg \
                 pytest pytest-parallel pytest-xdist pytest-html pytest-sugar pytest-randomly \
                 pytest-emoji pytest-icdiff pytest-asyncio pytest-rerunfailures pytest-repeat \
                 cocotb cocotb_bus cocotb-test cocotb-coverage cocotbext-axi

# VSCode
FROM cocotb as vscode
# rpm --import https://packages.microsoft.com/keys/microsoft.asc && sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
# yum -y install code

# VSCode Remote Env
# COPY resources/code-server-install.sh /usr/bin/
# RUN chmod +x /usr/bin/code-server-install.sh
RUN curl -fsSL https://code-server.dev/install.sh | sh
EXPOSE 8080
RUN mkdir -p ~/.config/code-server \
    && touch ~/.config/code-server/config.yaml \
    && sed -i.bak 's/auth: password/auth: none/' ~/.config/code-server/config.yaml

# Quality of Life Additions
FROM vscode as qol
RUN yum -y install wget htop sudo vim nano cmake openssl zsh teroshdl firefox dos2unix
# RUN yum groupinstall "Development tools"

# RUN curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh
# RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
# RUN echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>! ~/.zshrc
# RUN git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
# RUN echo 'source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting' >>! ~/.zshrc
# # RUN sed -i 's/_THEME=\"robbyrussel\"/_THEME=\"linuxonly\"/g' ~/.zshrc
# RUN chsh -s /bin/zsh


COPY resources/start-code-server.sh /usr/bin/
COPY resources/start-modelsim.sh /usr/bin/
COPY resources/startup.sh /usr/bin/
RUN chmod +x /usr/bin/start-code-server.sh \
    && chmod +x /usr/bin/start-modelsim.sh \
    && chmod +x /usr/bin/startup.sh
# RUN echo "(/usr/bin/start-code-server.sh &> /tmp/code-server.log)" >> ~/.bashrc

# VNC Server for GUI applications
FROM qol as vnc
RUN yum -y install xorg-x11-server-Xvfb x11vnc xterm openbox
ENV WINDOW_MANAGER="openbox"
RUN sed -ri "s/<number>4<\/number>/<number>1<\/number>/" /etc/xdg/openbox/rc.xml \
    && git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify
EXPOSE 5900 6080
COPY resources/novnc-index.html /opt/novnc/index.html
COPY resources/start-vnc-session.sh /usr/bin/
RUN chmod +x /usr/bin/start-vnc-session.sh \
    && pip3 install numpy \
    && echo "export DISPLAY=:0" >> ~/.bashrc \
    && echo "[ ! -e /tmp/.X0-lock ] && (/usr/bin/start-vnc-session.sh &> /tmp/display-\${DISPLAY}.log)" >> ~/.bashrc

# User [coder:coder]
# RUN useradd -ms /bin/bash coder -m -G wheel,root -p "$(openssl passwd -1 coder)"
# RUN usermod -aG wheel coder
# USER coder
# ENV USER=coder
# WORKDIR /home/coder

FROM vnc as final
RUN mkdir -p /workspaces/logs
WORKDIR /workspaces/
COPY . /workspaces/toolflow
#ENTRYPOINT /usr/bin/startup.sh
RUN chmod +rw /root/ -R

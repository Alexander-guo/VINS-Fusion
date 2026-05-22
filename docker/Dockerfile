# ====================================================================
# Base image
# ====================================================================
FROM osrf/ros:noetic-desktop-full

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    ROS_DISTRO=noetic \
    XDG_RUNTIME_DIR=/tmp/runtime-root

# ====================================================================
# Create non-root user matching host UID/GID (for volume access)
# ====================================================================
ARG USERNAME=root
ARG USER_UID=1000
ARG USER_GID=1000

# Create a user only if not root
RUN if [ "$USERNAME" != "root" ]; then \
      if ! getent group ${USER_GID} >/dev/null; then \
        groupadd --gid ${USER_GID} ${USERNAME}; \
      else \
        echo "GID ${USER_GID} already exists, reusing existing group"; \
        group_name=$(getent group ${USER_GID} | cut -d: -f1); \
        usermod --gid ${USER_GID} ${USERNAME} 2>/dev/null || true; \
      fi && \
      useradd --uid $USER_UID --gid $USER_GID -m $USERNAME && \
      apt-get update && apt-get install -y sudo && \
      echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
      chmod 0440 /etc/sudoers.d/$USERNAME; \
    fi

# ====================================================================
# Install system dependencies
# ====================================================================
ENV CERES_VERSION="1.12.0"
ENV CATKIN_WS=/catkin_ws

RUN apt-get update && apt-get install -y \
    build-essential cmake \
    x11-apps mesa-utils libgl1 \
    xterm vim gdb bash bash-completion wget curl unzip git tree \
    libatlas-base-dev \
    libeigen3-dev \
    libgoogle-glog-dev \
    libsuitesparse-dev \
    python3-catkin-tools \
    ros-$ROS_DISTRO-cv-bridge \
    ros-$ROS_DISTRO-image-transport \
    ros-$ROS_DISTRO-message-filters \
    ros-$ROS_DISTRO-tf \
    ros-$ROS_DISTRO-foxglove-bridge && \
    rm -rf /var/lib/apt/lists/* 

# Build and install Ceres
RUN git clone https://ceres-solver.googlesource.com/ceres-solver && \
    cd ceres-solver && \
    git checkout tags/${CERES_VERSION} && \
    mkdir build && cd build && \
    cmake .. && \
    make -j"$(nproc)" install && \
    rm -rf ../../ceres-solver && \
    mkdir -p $CATKIN_WS/src/VINS-Fusion/


# ====================================================================
# Create workspace and clone repo and build 
# ====================================================================
# Set working directory
WORKDIR $CATKIN_WS

# Copy VINS-Fusion as root so the files are created correctly
COPY ./ $CATKIN_WS/src/VINS-Fusion/
# use the following line if you only have this dockerfile
# RUN git clone https://github.com/HKUST-Aerial-Robotics/VINS-Fusion.git src/VINS-Fusion/

# Ensure the workspace is owned by the intended non-root UID/GID, then switch user
RUN chown -R $USER_UID:$USER_GID $CATKIN_WS
USER $USERNAME

# Build VINS-Fusion
ENV TERM="xterm"
ENV PYTHONIOENCODING="UTF-8"

# Use bash for subsequent RUN commands
SHELL ["/bin/bash", "-c"]

# Debug: show workspace state before running catkin
RUN echo "[DEBUG] CATKIN_WS=$CATKIN_WS" && \
    echo "[DEBUG] ls /:" && ls -la / || true && \
    echo "[DEBUG] ls $CATKIN_WS:" && ls -la $CATKIN_WS || true && \
    echo "[DEBUG] env CATKIN_WS:" && env | grep CATKIN_WS || true && \
    echo "[DEBUG] whoami and id:" && whoami && id || true 

RUN source "/opt/ros/$ROS_DISTRO/setup.bash" && \
    catkin config --extend "/opt/ros/$ROS_DISTRO" --cmake-args -DCMAKE_BUILD_TYPE=Release && \
    catkin build && \
    echo "source $CATKIN_WS/devel/setup.bash" >> ~/.bashrc

RUN python3 -m venv $CATKIN_WS/.venv && \
    source $CATKIN_WS/.venv/bin/activate && \
    pip install --no-cache-dir -r $CATKIN_WS/src/VINS-Fusion/requirements.txt && \
    echo "source $CATKIN_WS/.venv/bin/activate" >> ~/.bashrc

# ====================================================================
# Default command
# ====================================================================
CMD ["bash", "-l"]
FROM osrf/ros:jazzy-desktop-full

ENV COLCON_WS=/root/ros2_ws

RUN apt-get update && apt-get install -y --no-install-recommends \
      sudo curl nano python3-pip \
      ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
      ros-${ROS_DISTRO}-rmw-zenoh-cpp \
      ros-${ROS_DISTRO}-rosbag2-storage-mcap \
    && curl -fsSL --retry 3 -o /tmp/vgl.deb \
      https://github.com/VirtualGL/virtualgl/releases/download/3.1.1/virtualgl_3.1.1_amd64.deb \
    && apt-get install -y /tmp/vgl.deb \
    && rm -rf /tmp/vgl.deb /var/lib/apt/lists/*

WORKDIR ${COLCON_WS}

# Add your own packages here:

RUN bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && \
    cd ${COLCON_WS} && \
    colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release"

ENV VGL_DISPLAY=egl0 \
    NVIDIA_DRIVER_CAPABILITIES=all

COPY docker/requirements.txt ./requirements.txt
RUN python3 -m pip config set global.break-system-packages true && \
    pip3 install --no-cache-dir -r requirements.txt

RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc && \
    echo "source ${COLCON_WS}/install/setup.bash" >> ~/.bashrc

CMD ["bash"]


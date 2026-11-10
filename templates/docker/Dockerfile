# ROS 2 development image. Your source is bind-mounted, not baked in.
FROM osrf/ros:jazzy-desktop-full

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl nano vim tmux python3-pip python3-venv \
      ros-${ROS_DISTRO}-rosbag2-storage-mcap \
    && curl -fsSL --retry 3 -o /tmp/vgl.deb \
      https://github.com/VirtualGL/virtualgl/releases/download/3.1.1/virtualgl_3.1.1_amd64.deb \
    && apt-get install -y /tmp/vgl.deb \
    && rm -rf /tmp/vgl.deb /var/lib/apt/lists/*

# Add your own packages here, in a new RUN so rebuilds stay fast.

# The image's ubuntu user has your workspace uid, 1000, so files in ros2_ws stay yours.
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu \
    && echo 'source /opt/ros/$ROS_DISTRO/setup.bash; [ -f ~/ros2_ws/install/setup.bash ] && source ~/ros2_ws/install/setup.bash' >> /home/ubuntu/.bashrc

ENV VGL_DISPLAY=egl0 \
    NVIDIA_DRIVER_CAPABILITIES=all

USER ubuntu
WORKDIR /home/ubuntu/ros2_ws

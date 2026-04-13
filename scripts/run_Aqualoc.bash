#!/bin/bash

DATASET_BAG_PATH=$1
WS_PATH="/home/ws"
AQUALOC_CONFIG_PATH="${WS_PATH}/src/VINS-Fusion/config/aqualoc"

run_VINS_FUSION() {
    local config_file="$1"
    local bag_file="$2"
    local is_mono_imu="$3"

    config_base_name=$(basename "${config_file}" .yaml)
    bag_name=$(basename "${bag_file}" .bag)

    # start roslaunch in background and capture its PID
    roslaunch vins vins_rviz.launch >"${WS_PATH}/logs/vins_launch.${bag_name}.${config_base_name}.log" 2>&1 &
    LAUNCH_PID=$!

    # wait a short while for ROS master to come up (with timeout)
    START_WAIT=0
    until rostopic list >/dev/null 2>&1; do
        sleep 0.1
        START_WAIT=$((START_WAIT+1))
        if [ ${START_WAIT} -gt 100 ]; then
            echo "roslaunch did not start properly (pid=${LAUNCH_PID}). Check ${WS_PATH}/logs/vins_launch.${bag_name}.${config_base_name}.log"
            kill ${LAUNCH_PID} >/dev/null 2>&1 || true
            return 1
        fi
    done

    sleep 3  # additional wait to ensure everything is up

    # start vins node in background
    rosrun vins vins_node "${config_file}" >"${WS_PATH}/logs/vins_node.${bag_name}.${config_base_name}.log" 2>&1 &
    NODE_PID=$!

    sleep 4  # wait for vins node to initialize

    # play bag in foreground so the script waits until completion
    rosbag play --clock "${bag_file}"
    if [ $? -ne 0 ]; then
        echo "Error occurred while processing ${bag_file}"
        # try to clean up
        kill ${NODE_PID} >/dev/null 2>&1 || true
        kill ${LAUNCH_PID} >/dev/null 2>&1 || true
        return 1
    fi
    echo "Finished processing ${bag_file}"

    # stop vins node and roslaunch
    kill ${NODE_PID} >/dev/null 2>&1 || true
    kill ${LAUNCH_PID} >/dev/null 2>&1 || true

    # Determine output directories based on configuration
    if [ "${is_mono_imu}" = true ]; then
        POSE_DIR="${WS_PATH}/output/pose/VINS-Fusion_MonoIMU/${bag_name}"
        TIME_DIR="${WS_PATH}/output/time/VINS-Fusion_MonoIMU/${bag_name}"
    else
        POSE_DIR="${WS_PATH}/output/pose/VINS-Fusion_StereoIMU/${bag_name}"
        TIME_DIR="${WS_PATH}/output/time/VINS-Fusion_StereoIMU/${bag_name}"
    fi

    # Create directories if they don't exist
    mkdir -p "${POSE_DIR}" "${TIME_DIR}"

    # Move output files if they exist
    if [ -f "${WS_PATH}/output/vio.txt" ]; then
        mv "${WS_PATH}/output/vio.txt" "${POSE_DIR}/vio.txt"
    else
        echo "Warning: ${WS_PATH}/output/vio.txt not found"
    fi
    if [ -f "${WS_PATH}/output/vio_time.txt" ]; then
        mv "${WS_PATH}/output/vio_time.txt" "${TIME_DIR}/vio_time.txt"
    else
        echo "Warning: ${WS_PATH}/output/vio_time.txt not found"
    fi
}

cd "${WS_PATH}" || exit 1
source devel/setup.bash

if [ ! -d "${WS_PATH}/output" ]; then
    mkdir -p "${WS_PATH}/output"
fi

found_bag=0
for bag_file in "${DATASET_BAG_PATH}"/archaeo/bag_files/*.bag "${DATASET_BAG_PATH}"/harbor/bag_files/*.bag; do
    [ -e "${bag_file}" ] || continue
    found_bag=1
    bag_name=$(basename "${bag_file}" .bag)
    echo "Running bag file: ${bag_file}"

    # run mono imu setting only
    if [ -d "${WS_PATH}/output/pose/VINS-Fusion_MonoIMU/${bag_name}" ] || [ -d "${WS_PATH}/output/time/VINS-Fusion_MonoIMU/${bag_name}" ]; then
        echo "Mono IMU output already exists. Skipping ..."
    else
        is_mono_imu=true
        config_file=${AQUALOC_CONFIG_PATH}/harbor_mono_imu_config.yaml
        if [[ "${bag_name}" == *"archaeo"* ]]; then
            config_file=${AQUALOC_CONFIG_PATH}/archaeo_mono_imu_config.yaml
        fi
        run_VINS_FUSION "${config_file}" "${bag_file}" "${is_mono_imu}"
        echo "Completed mono imu setting for ${bag_file}"
        sleep 4
    fi
done

if [ ${found_bag} -eq 0 ]; then
    echo "Warning: No bag files found under ${DATASET_BAG_PATH}/archaeo/bag_files or ${DATASET_BAG_PATH}/harbor/bag_files"
fi

echo "All bag files processed."
#!/bin/bash

# # Add this line to avoid port 11311 conflict with VS Code
# export ROS_MASTER_URI=http://localhost:11312

DATASET_PATH=$1
WS_PATH="/home/ws"
LAMARIA_CONFIG_PATH="${WS_PATH}/src/VINS-Fusion/config/lamaria"

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

for data_seq in ${DATASET_PATH}/*; do
    [ ! -d "${data_seq}" ] && continue
    
    bag_file=$(find "${data_seq}/rosbag" -maxdepth 1 -name "*.bag" -type f | head -1)
    if [ -z "$bag_file" ]; then
        echo "Warning: No bag file found in ${data_seq}/rosbag, skipping"
        continue
    fi
    bag_name=$(basename "${bag_file}" .bag)

    if [ -d "${WS_PATH}/output/pose/VINS-Fusion_MonoIMU/${bag_name}" ] || [ -d "${WS_PATH}/output/time/VINS-Fusion_MonoIMU/${bag_name}" ]; then
        echo "Output directory already exists. Skipping ${bag_name}."
        continue
    fi

    echo "Running bag file: ${bag_file}"
    
    # # run stereo imu setting
    # if [[ ${bag_name} == R_*_hard ]] || [[ ${bag_name} == sequence_1_* ]]; then
    #     # use different config for LaMaria_Indoor bags
    #     config_file=${LAMARIA_CONFIG_PATH}/stereo_imu_config2.yaml
    # else
    #     config_file=${LAMARIA_CONFIG_PATH}/stereo_imu_config1.yaml
    # fi
    # is_mono_imu=false
    # run_VINS_FUSION "${config_file}" "${bag_file}" “${is_mono_imu}”
    # echo "Completed stereo imu setting for ${bag_file}"
    # sleep 4

    # run mono imu setting
    if [[ ${bag_name} == R_*_hard ]] || [[ ${bag_name} == sequence_1_* ]]; then
        # use different config for LaMaria_Indoor bags
        config_file=${LAMARIA_CONFIG_PATH}/mono_imu_config2.yaml
    else
        config_file=${LAMARIA_CONFIG_PATH}/mono_imu_config1.yaml
    fi
    is_mono_imu=true
    run_VINS_FUSION "${config_file}" "${bag_file}" "${is_mono_imu}"
    echo "Completed mono imu setting for ${bag_file}"
    sleep 4
done

echo "All bag files processed."
#!/bin/bash

DATASET_BAG_PATH=$1
WS_PATH="/home/ws"
EUROC_CONFIG_PATH="${WS_PATH}/src/VINS-Fusion/config/uzhfpv"

run_VINS_FUSION() {
    local config_file="$1"
    local bag_file="$2"

    # start roslaunch in background and capture its PID
    roslaunch vins vins_rviz.launch >"${WS_PATH}/logs/vins_launch.${config_base_name}.log" 2>&1 &
    LAUNCH_PID=$!

    # wait a short while for ROS master to come up (with timeout)
    START_WAIT=0
    until rostopic list >/dev/null 2>&1; do
        sleep 0.1
        START_WAIT=$((START_WAIT+1))
        if [ ${START_WAIT} -gt 100 ]; then
            echo "roslaunch did not start properly (pid=${LAUNCH_PID}). Check ${WS_PATH}/logs/vins_launch.${config_base_name}.log"
            kill ${LAUNCH_PID} >/dev/null 2>&1 || true
            return 1
        fi
    done

    sleep 4  # additional wait to ensure everything is up

    # start vins node in background
    rosrun vins vins_node "${config_file}" >"${WS_PATH}/logs/vins_node.${config_base_name}.log" 2>&1 &
    NODE_PID=$!

    # # ensure output directory exists
    # mkdir -p "${WS_PATH}/output"

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

    # remove trailing "_config" if present
    config_base_name=$(basename "${config_file}" .yaml)
    config_base_name=${config_base_name%_config}
    bag_name=$(basename "${bag_file}" .bag)

    # split bag_name by '_' and take the third field, which indicates the sequence index
    bag_name=$(echo "${bag_name}" | awk -F'_' '{print $3}')

    # rename output files if they exist
    if [ -f "${WS_PATH}/output/vio.txt" ]; then
        mv "${WS_PATH}/output/vio.txt" "${WS_PATH}/output/vio_${config_base_name}_${bag_name}.txt"
    else
        echo "Warning: ${WS_PATH}/output/vio.txt not found"
    fi
    if [ -f "${WS_PATH}/output/vio_time.txt" ]; then
        mv "${WS_PATH}/output/vio_time.txt" "${WS_PATH}/output/vio_time_${config_base_name}_${bag_name}.txt"
    else
        echo "Warning: ${WS_PATH}/output/vio_time.txt not found"
    fi
}

cd "${WS_PATH}" || exit 1
source devel/setup.bash

for bag_file in ${DATASET_BAG_PATH}/*.bag; do
    echo "Running bag file: ${bag_file}"
    
    bag_name=$(basename "${bag_file}" .bag)

    if [[ ${bag_name} == indoor_45* ]]; then
        # run mono imu setting for indoor_45 bags
        config_file=${EUROC_CONFIG_PATH}/uzhfpv_indoor_45_mono_imu_config.yaml
        run_VINS_FUSION "${config_file}" "${bag_file}"
        echo "Completed mono imu setting for ${bag_file}"
        sleep 4

        # run stereo imu setting for indoor_45 bags
        config_file=${EUROC_CONFIG_PATH}/uzhfpv_indoor_45_stereo_imu_config.yaml
        run_VINS_FUSION "${config_file}" "${bag_file}"
        echo "Completed stereo imu setting for ${bag_file}"
        sleep 4
    fi

    if [[ ${bag_name} == outdoor_45* ]]; then
        # run mono imu setting for outdoor_45 bags
        config_file=${EUROC_CONFIG_PATH}/uzhfpv_outdoor_45_mono_imu_config.yaml
        run_VINS_FUSION "${config_file}" "${bag_file}"
        echo "Completed mono imu setting for ${bag_file}"
        sleep 4

        # run stereo imu setting for outdoor_45 bags
        config_file=${EUROC_CONFIG_PATH}/uzhfpv_outdoor_45_stereo_imu_config.yaml
        run_VINS_FUSION "${config_file}" "${bag_file}"
        echo "Completed stereo imu setting for ${bag_file}"
        sleep 4
    fi
    
    if [[ ${bag_name} == indoor_forward* ]]; then
        # run mono imu setting for indoor_forward bags
        config_file=${EUROC_CONFIG_PATH}/uzhfpv_indoor_fwd_mono_imu_config.yaml
        run_VINS_FUSION "${config_file}" "${bag_file}"
        echo "Completed mono imu setting for ${bag_file}"
        sleep 4

        # run stereo imu setting for indoor_forward bags
        config_file=${EUROC_CONFIG_PATH}/uzhfpv_indoor_fwd_stereo_imu_config.yaml
        run_VINS_FUSION "${config_file}" "${bag_file}"
        echo "Completed stereo imu setting for ${bag_file}"
        sleep 4
    fi

    if [[ ${bag_name} == outdoor_forward* ]]; then
        # run mono imu setting for outdoor_forward bags
        config_file=${EUROC_CONFIG_PATH}/uzhfpv_outdoor_fwd_mono_imu_config.yaml
        run_VINS_FUSION "${config_file}" "${bag_file}"
        echo "Completed mono imu setting for ${bag_file}"
        sleep 4

        # run stereo imu setting for outdoor_forward bags
        config_file=${EUROC_CONFIG_PATH}/uzhfpv_outdoor_fwd_stereo_imu_config.yaml
        run_VINS_FUSION "${config_file}" "${bag_file}"
        echo "Completed stereo imu setting for ${bag_file}"
        sleep 4
    fi
done

echo "All bag files processed."
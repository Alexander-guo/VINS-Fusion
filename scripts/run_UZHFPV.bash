#!/bin/bash

DATASET_BAG_PATH=$1

# Resolve workspace path for host or container
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
DEFAULT_WS=$(cd "${REPO_ROOT}/../.." && pwd)
WS_PATH="${CATKIN_WS:-${DEFAULT_WS}}"
UZHFPV_CONFIG_PATH="${REPO_ROOT}/config/uzhfpv"

OUTPUT_PATH=$(cd "${DATASET_BAG_PATH}/.." && pwd)/VINS-FUSION_output

# Make globbing for missing bags safe
shopt -s nullglob

process_sequence_pair() {
    local bag_file="$1"
    local config_mono="$2"
    local config_stereo="$3"

    # # run mono imu setting
    # is_mono_imu=true 
    # config_file_tmp=$(prepare_config "${config_mono}" "${OUTPUT_PATH}")
    # run_VINS_FUSION "${config_file_tmp}" "${bag_file}" "${is_mono_imu}"
    # rm -f "${config_file_tmp}"
    # echo "Completed mono imu setting for ${bag_file}"
    # sleep 4

    # run stereo imu setting 
    is_mono_imu=false
    config_file_tmp=$(prepare_config "${config_stereo}" "${OUTPUT_PATH}")
    run_VINS_FUSION "${config_file_tmp}" "${bag_file}" "${is_mono_imu}"
    rm -f "${config_file_tmp}"
    echo "Completed stereo imu setting for ${bag_file}"
    sleep 4
}

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

    sleep 4  # additional wait to ensure everything is up

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
        POSE_DIR="${OUTPUT_PATH}/pose/VINS-Fusion_MonoIMU/${bag_name}"
        TIME_DIR="${OUTPUT_PATH}/time/VINS-Fusion_MonoIMU/${bag_name}"
    else
        POSE_DIR="${OUTPUT_PATH}/pose/VINS-Fusion_StereoIMU/${bag_name}"
        TIME_DIR="${OUTPUT_PATH}/time/VINS-Fusion_StereoIMU/${bag_name}"
    fi

    # Create directories if they don't exist
    mkdir -p "${POSE_DIR}" "${TIME_DIR}"

    # Move output files if they exist
    if [ -f "${OUTPUT_PATH}/vio.txt" ]; then
        mv "${OUTPUT_PATH}/vio.txt" "${POSE_DIR}/vio.txt"
    else
        echo "Warning: ${OUTPUT_PATH}/vio.txt not found"
    fi
    if [ -f "${OUTPUT_PATH}/vio_time.txt" ]; then
        mv "${OUTPUT_PATH}/vio_time.txt" "${TIME_DIR}/vio_time.txt"
    else
        echo "Warning: ${OUTPUT_PATH}/vio_time.txt not found"
    fi
}

prepare_config() {
    local src_config="$1"
    local output_dir="$2"
    local tmp_config
    local config_dir
    config_dir=$(cd "$(dirname "${src_config}")" && pwd)
    tmp_config=$(mktemp "${config_dir}/.$(basename "${src_config}" .yaml).XXXXXX.yaml")

    sed -E \
        -e "s|^(output_path:).*$|\1 \"${output_dir}\"|" \
        -e "s|^(pose_graph_save_path:).*$|\1 \"${output_dir}/pose_graph\"|" \
        "${src_config}" > "${tmp_config}"

    echo "${tmp_config}"
}

cd "${WS_PATH}" || exit 1
source devel/setup.bash

if [ ! -d "${WS_PATH}/logs" ]; then
    mkdir -p "${WS_PATH}/logs"
fi

bags=("${DATASET_BAG_PATH}"/*.bag)
if [ ${#bags[@]} -eq 0 ]; then
    echo "No .bag files found in ${DATASET_BAG_PATH}"
    exit 1
fi

if [ ! -d "${OUTPUT_PATH}" ]; then
    mkdir -p "${OUTPUT_PATH}"
fi

for bag_file in "${bags[@]}"; do
    bag_name=$(basename "${bag_file}" .bag)
    if [ -d "${OUTPUT_PATH}/pose/VINS-Fusion_StereoIMU/${bag_name}" ] || [ -d "${OUTPUT_PATH}/time/VINS-Fusion_StereoIMU/${bag_name}" ]; then
        echo "Output directory already exists. Skipping ${bag_name}."
        continue
    fi
    echo "Running bag file: ${bag_file}"
    
    case "${bag_name}" in
        indoor_45*)
            process_sequence_pair "${bag_file}" \
                "${UZHFPV_CONFIG_PATH}/uzhfpv_indoor_45_mono_imu_config.yaml" \
                "${UZHFPV_CONFIG_PATH}/uzhfpv_indoor_45_stereo_imu_config.yaml"
            ;;
        outdoor_45*)
            process_sequence_pair "${bag_file}" \
                "${UZHFPV_CONFIG_PATH}/uzhfpv_outdoor_45_mono_imu_config.yaml" \
                "${UZHFPV_CONFIG_PATH}/uzhfpv_outdoor_45_stereo_imu_config.yaml"
            ;;
        indoor_forward*)
            process_sequence_pair "${bag_file}" \
                "${UZHFPV_CONFIG_PATH}/uzhfpv_indoor_fwd_mono_imu_config.yaml" \
                "${UZHFPV_CONFIG_PATH}/uzhfpv_indoor_fwd_stereo_imu_config.yaml"
            ;;
        outdoor_forward*)
            process_sequence_pair "${bag_file}" \
                "${UZHFPV_CONFIG_PATH}/uzhfpv_outdoor_fwd_mono_imu_config.yaml" \
                "${UZHFPV_CONFIG_PATH}/uzhfpv_outdoor_fwd_stereo_imu_config.yaml"
            ;;
        *)
            echo "Warning: unknown sequence pattern for ${bag_name}, skipping"
            ;;
    esac
done

echo "All bag files processed."
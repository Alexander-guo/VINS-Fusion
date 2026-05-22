#!/bin/bash

# ==========================================
# Resource Usage Evaluation Script for VINS-Fusion
# This script processes all .bag files in a specified dataset directory,
# runs VINS-Fusion on them, and collects resource usage data.
# It supports both stereo and mono configurations based on the provided config files.
# Usage: ./resource_usage_eval.bash <dataset_directory>
# ==========================================

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DEFAULT_WS=$(cd "${SCRIPT_DIR}/../../.." && pwd)
WS_PATH="${CATKIN_WS:-${DEFAULT_WS}}"
source ${WS_PATH}/devel/setup.bash

DATASET_DIR=$1

if [ -z "$DATASET_DIR" ]; then
    echo "Usage: $0 <dataset_directory>"
    exit 1
fi

RESULT_ROOT="$DATASET_DIR/../resource_res"
LAUNCH_PKG="vins"
SUPPORT_STEREO=true
SUPPORT_MONO=true


if [ ! -d "$DATASET_DIR" ]; then
    echo "Error: Dataset directory $DATASET_DIR does not exist."
    exit 1
fi

mkdir -p "$RESULT_ROOT"

# track temporary config files so we can clean them up on exit
TMP_CONFIGS=()
cleanup_tmp_configs() {
    if [ "${#TMP_CONFIGS[@]}" -gt 0 ]; then
        rm -f "${TMP_CONFIGS[@]}" >/dev/null 2>&1 || true
    fi
}
trap cleanup_tmp_configs EXIT INT TERM

# Create an array of bag files to count them accurately
files=("$DATASET_DIR"/*.bag)
total_runs=0
if [ "$SUPPORT_STEREO" = true ]; then
    total_runs=3
fi
if [ "$SUPPORT_MONO" = true ]; then
    total_runs=$((total_runs + 5))
fi
current=0

# Check if there are actually files to process
if [ "$total_runs" -eq 0 ]; then
    echo "No .bag files found in $DATASET_DIR"
    exit 0
fi

# Function to draw the progress bar
# Usage: draw_progress_bar <current> <total> <text>
draw_progress_bar() {
    local _current=$1
    local _total=$2
    local _text=$3
    
    # Calculate percentage
    local _percent=$((100 * _current / _total))
    # Define bar width (e.g., 20 chars)
    local _width=20
    local _filled=$((_width * _percent / 100))
    local _empty=$((_width - _filled))
    
    # Create the bar string (e.g., "#####")
    local _bar=$(printf "%${_filled}s" | tr ' ' '#')
    local _spaces=$(printf "%${_empty}s" | tr ' ' '.')
    
    # Print the bar using \r to overwrite the line
    # \r returns cursor to start of line, allowing animation
    printf "\r[%s%s] %d%% (%d/%d) %s\033[K" "$_bar" "$_spaces" "$_percent" "$_current" "$_total" "$_text"
}

prepare_config() {
    local src_config="$1"
    local output_dir="$2"
    local tmp_config
    local config_dir
    config_dir=$(cd "$(dirname "${src_config}")" && pwd)
    tmp_config=$(mktemp "${config_dir}/.$(basename "${src_config}" .yaml).XXXXXX.yaml")

    # remember to cleanup this temp file on exit
    TMP_CONFIGS+=("${tmp_config}")

    sed -E \
        -e "s|^(output_path:).*$|\1 \"${output_dir}\"|" \
        -e "s|^(pose_graph_save_path:).*$|\1 \"${output_dir}/pose_graph\"|" \
        "${src_config}" > "${tmp_config}"

    echo "${tmp_config}"
}

run_VINS_FUSION() {
    local config_file="$1"
    local bag_file="$2"
    local mode="$3"

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

    POSE_DIR="${RESULT_ROOT}/pose/vinsfusion_${mode}/${bag_name}"
    TIME_DIR="${RESULT_ROOT}/time/vinsfusion_${mode}/${bag_name}"

    # Create directories if they don't exist
    mkdir -p "${POSE_DIR}" "${TIME_DIR}"

    # Move output files if they exist
    if [ -f "${RESULT_ROOT}/vio.txt" ]; then
        mv "${RESULT_ROOT}/vio.txt" "${POSE_DIR}/vio.txt"
    else
        echo "Warning: ${RESULT_ROOT}/vio.txt not found"
    fi
    if [ -f "${RESULT_ROOT}/vio_time.txt" ]; then
        mv "${RESULT_ROOT}/vio_time.txt" "${TIME_DIR}/vio_time.txt"
    else
        echo "Warning: ${RESULT_ROOT}/vio_time.txt not found"
    fi
}

echo "Starting batch processing for $total_runs datasets..."

modes=()
if [ "$SUPPORT_STEREO" = true ]; then
    modes+=("stereo")
fi

if [ "$SUPPORT_MONO" = true ]; then
    modes+=("mono")
fi


## Loop through all .bag files
for mode in "${modes[@]}"; do
    RESOURCE_DIR="${RESULT_ROOT}/resource/vinsfusion_${mode}"

    for bag_file in "${files[@]}"; do
        # Skip the bag files for stereo
        filename=$(basename -- "$bag_file")
        dataset_name="${filename%.*}"
        echo "Processing dataset: $dataset_name with mode: $mode"

        if [ "$mode" == "stereo" ]; then
            if [[ "$dataset_name" == "harbor_sequence_6" ]] || [[ "$dataset_name" == "R_02_easy" ]]; then
                continue
            fi
        fi

        # Setup configuration file for current dataset and mode
        if [ "$dataset_name" == "V1_01_easy" ]; then
            if [ "$mode" == "stereo" ]; then
                CONFIG_FILE="${SCRIPT_DIR}/../config/euroc/euroc_stereo_imu_config.yaml"
            else
                CONFIG_FILE="${SCRIPT_DIR}/../config/euroc/euroc_mono_imu_config.yaml"
            fi
        elif [ "$dataset_name" == "indoor_45_12_snapdragon_with_gt" ]; then
            if [ "$mode" == "stereo" ]; then
                CONFIG_FILE="${SCRIPT_DIR}/../config/uzhfpv/uzhfpv_indoor_45_stereo_imu_config.yaml"
            else
                CONFIG_FILE="${SCRIPT_DIR}/../config/uzhfpv/uzhfpv_indoor_45_mono_imu_config.yaml"
            fi
        elif [ "$dataset_name" == "R_02_easy" ]; then
            CONFIG_FILE="${SCRIPT_DIR}/../config/lamaria/mono_imu_config1.yaml"
        elif [[ "$dataset_name" == 2024-11-15-11-37-15* ]]; then
            if [ "$mode" == "stereo" ]; then
                CONFIG_FILE="${SCRIPT_DIR}/../config/grandtour/stereo_imu_config.yaml"
            else
                CONFIG_FILE="${SCRIPT_DIR}/../config/grandtour/mono_imu_config.yaml"
            fi
        elif [ "$dataset_name" == "harbor_sequence_6" ]; then
            CONFIG_FILE="${SCRIPT_DIR}/../config/aqualoc/harbor_mono_imu_config.yaml"

        fi

        if [ ! -d "${RESOURCE_DIR}/${dataset_name}" ]; then
            mkdir -p "${RESOURCE_DIR}/${dataset_name}"
        else
            echo "Directory $RESOURCE_DIR already exists. Skipping dataset $dataset_name to avoid overwriting results."
            ((current++))
            continue
        fi

        if [ -z "${CONFIG_FILE:-}" ] || [ ! -f "$CONFIG_FILE" ]; then
            echo "Warning: No config file found for dataset $dataset_name in mode $mode. Skipping."
            ((current++))
            continue
        fi

        # Update progress bar BEFORE processing
        draw_progress_bar "$current" "$total_runs" "-> Processing: $dataset_name"

        # Start monitoring CPU usage in the background
        python3 $SCRIPT_DIR/monitor_cpu_only.py --output "$RESOURCE_DIR/$dataset_name/monitor_cpu_only.csv" --interval 0.2 & MONITOR_PID=$!

        config_file_tmp=$(prepare_config "${CONFIG_FILE}" "${RESULT_ROOT}") 
        run_VINS_FUSION "${config_file_tmp}" "${bag_file}" "${mode}"

        # remove the temporary config created for this run
        rm -f "${config_file_tmp}" || true

        # Increment counter
        ((current++))
    done
done

# Final update to show 100%
draw_progress_bar "$current" "$total_runs" "Done!"
echo "" 
echo "All datasets have been processed!"


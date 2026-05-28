# VINS-Fusion Benchmarking
<img src="https://github.com/HKUST-Aerial-Robotics/VINS-Fusion/blob/master/support_files/image/vins_logo.png" width = 55% height = 55% div align=left />
<img src="https://github.com/HKUST-Aerial-Robotics/VINS-Fusion/blob/master/support_files/image/kitti.png" width = 34% height = 34% div align=center />

[VINS-Fusion](https://github.com/HKUST-Aerial-Robotics/VINS-Fusion) is an optimization-based multi-sensor state estimator, which achieves accurate self-localization for autonomous applications (drones, cars, and AR/VR). VINS-Fusion is an extension of [VINS-Mono](https://github.com/HKUST-Aerial-Robotics/VINS-Mono), which supports multiple visual-inertial sensor types (mono camera + IMU, stereo cameras + IMU, even stereo cameras only).

We evaluate VINS-Fusion on several public datasets, including [EuRoC MAV](https://projects.asl.ethz.ch/datasets/doku.php?id=kmavvisualinertialdatasets), [UZH-FPV](https://fpv.ifi.uzh.ch/), [LaMAria](https://github.com/cvg/lamaria), [GrandTour](https://grand-tour.leggedrobotics.com/) and [Aqualoc](https://www.lirmm.fr/aqualoc/) Dataset.

## 1.Prerequisites
First, make sure you have [docker](https://docs.docker.com/install/linux/docker-ce/ubuntu/) and [docker-compose](https://docs.docker.com/compose/install/) installed on your machine.

Clone the repository and navigate to the docker folder:
```bash
mkdir -p vinsfusion_benchmark_ws/src
cd vinsfusion_benchmark_ws/src
git clone https://github.com/Alexander-guo/VINS-Fusion.git
cd vinsfusion_benchmark_ws/src/VINS-Fusion/
```

Then, modify the mounted host dataset path in `docker/docker-compose.yml` in `volumes` field to your path accordingly. 

To benchmark, the dataset should have the following structure:

<details>
<summary><u>Dataset structure</u></summary>

```text
datasets
|-- aqualoc
|   |-- archaeo
|   |   |-- archaeo_sequence_1.bag
|   |   |...
|   |   `-- archaeo_sequence_10.bag
|   `-- harbor
|       |-- harbor_sequence_1.bag
|       |-- ...
|       `-- harbor_sequence_7.bag
|-- euroc_mav
|   |-- MH_01_easy.bag
|   |-- ...
|   `-- V2_03_difficult.bag
|-- grand_tour/grand_tour_compressed
|   |-- 2024-10-01-11-29-55.bag
|   |-- ...
|   `-- 2024-12-09-11-28-28.bag
|-- lamaria
|   |-- add1
|   |   |-- sequence_1_19.bag
|   |   `-- sequence_1_20.bag
|   |-- add2
|   |   |-- sequence_2_11.bag
|   |   |-- ...
|   |   `-- sequence_5_12.bag
|   |-- cp
|   |   |-- R_11_5cp.bag
|   |   |-- R_12_10cp.bag
|   |   `-- R_13_15cp.bag
|   |-- easy
|   |   |-- R_01_easy.bag
|   |   |-- R_02_easy.bag
|   |   `-- R_03_easy.bag
|   |-- hard
|   |   |-- R_08_hard.bag
|   |   |-- R_09_hard.bag
|   |   `-- R_10_hard.bag
|   `-- medium
|       |-- R_04_medium.bag
|       |-- ...
|       `-- R_07_medium.bag
`-- uzh_fpv
    |-- uzhfpv_indoor
    |   |-- indoor_forward_10_snapdragon_with_gt.bag
    |   |-- ...
    |   `-- indoor_forward_9_snapdragon_with_gt.bag
    |-- uzhfpv_indoor_45
    |   |-- indoor_45_12_snapdragon_with_gt.bag
    |   |-- ...
    |   `-- indoor_45_4_snapdragon_with_gt.bag
    |-- uzhfpv_outdoor
    |   |-- outdoor_forward_1_snapdragon_with_gt.bag
    |   |-- outdoor_forward_3_snapdragon_with_gt.bag
    |   `-- outdoor_forward_5_snapdragon_with_gt.bag
    `-- uzhfpv_outdoor_45
        `-- outdoor_45_1_snapdragon_with_gt.bag
```

</details>


## 2. Run with Docker

Then, run the following command to build and run VINS-Fusion with docker:
```bash
# build docker image and run container, at repo root path run
chmod +x docker/compose-up.sh
./docker/compose-up.sh
```

If you want to run the container on Jetson/ARM edge devices, build the ARM64 image from `docker/Dockerfile.orin` and run it locally on the Jetson:
```bash
# at repo root

# (optional) ensure buildx is available and selected
docker buildx create --use --name vinsfusion-builder || docker buildx use vinsfusion-builder

# build ARM64 image with the Jetson-specific Dockerfile
docker buildx build -f docker/Dockerfile.orin \
    --platform linux/arm64 \
    -t vinsfusion-jetson:latest \
    --load .

# verify
docker inspect vinsfusion-jetson:latest | grep Architecture
# output as:
# "Architecture": "arm64",

# run the image on the Jetson (mount your datasets as needed)
docker run -it --rm \
    -v /path/to/your/datasets/on/host:/media/data \
    --name vinsfusion-jetson \
    vinsfusion-jetson:latest
```

## 3. Run VINS-Fusion on datasets
After the container is up, you can run VINS-Fusion with the following command on each dataset. 
* Run in batch (recommended):
```BASH 
# run Euroc MAV dataset
docker run -it -v /path/to/your/datasets/on/host:/media/data vins-fusion /bin/bash -lc "/catkin_ws/src/VINS-Fusion/scripts/run_EurocMAV.bash /media/data/<your_EurocMAV_bag_folder_path>"

# run UZH-FPV dataset
docker run -it -v /path/to/your/datasets/on/host:/media/data vins-fusion /bin/bash -lc "/catkin_ws/src/VINS-Fusion/scripts/run_UZHFPV.bash /media/data/<your_UZHFPV_bag_folder_path>"

# run LaMAria dataset
docker run -it -v /path/to/your/datasets/on/host:/media/data vins-fusion /bin/bash -lc "/catkin_ws/src/VINS-Fusion/scripts/run_LaMaria.bash /media/data/<your_LaMAria_bag_folder_path>"

# run GrandTour dataset
docker run -it -v /path/to/your/datasets/on/host:/media/data vins-fusion /bin/bash -lc "/catkin_ws/src/VINS-Fusion/scripts/run_GrandTour.bash /media/data/<your_GrandTour_bag_folder_path>"

# run Aqualoc dataset
docker run -it -v /path/to/your/datasets/on/host:/media/data vins-fusion /bin/bash -lc "/catkin_ws/src/VINS-Fusion/scripts/run_Aqualoc.bash /media/data/<your_Aqualoc_bag_folder_path>"
```

* Run with single bag file:
```BASH
## run with single bag file, take Euroc MAV dataset for example
# enter the running container
docker compose -f docker/docker-compose.yml exec vins-fusion bash

# Inside the container, run all three in separate shell tabs/terminals
roslaunch vins vins_rviz.launch
rosrun vins vins_node /catkin_ws/src/VINS-Fusion/config/euroc/euroc_stereo_imu_config.yaml
rosbag play /media/data/<your_bag_file>
```

The output will be saved as following structure under `/path/to/your/datasets/on/host`(run in batch) or under `/catkin_ws/output` in the container (run with single bag file):
```
├── YOUR_DATASET_FOLDER_ON_HOST
    |── datasets 
    |── VINS-FUSION_output
        ├── euroc_mav
            ├── pose
            │   └── VINS-Fusion_StereoIMU
            │       ├── sequence_1
            │       │   └── vio.txt
            │       └── sequence_2
            │           └── vio.txt
            └── time
                └── VINS-Fusion_StereoIMU
                    ├── sequence_1
                    │   └── vio_time.txt
                    └── sequence_2
                        └── vio_time.txt
```

* Resource usage evaluation:
```BASH
# run resource usage evaluation script for Euroc MAV dataset
docker run -it -v /path/to/your/datasets/on/host:/media/data vins-fusion /bin/bash -lc "/catkin_ws/src/VINS-Fusion/scripts/resource_usage_eval.bash /media/data/<resource_eval_dataset_folder_path>"
```
The resource usage evaluation script will run VINS-Fusion on all bag files in the specified dataset folder and save the output pose, time files and resource usage data (CPU, memory usage) under the folder `resource_res` with the following structure:
```
resource_eval
├── datasets
│   ├── 2024-11-15-11-37-15_compressed.bag
│   ├── ...
└── resource_res
    ├── pose
    │   ├── vinsfusion_mono
    │   │   ├── 2024-11-15-11-37-15_compressed
    │   │   │   └── vio.txt
    │   │   ├── ...
    │   └── vinsfusion_stereo
    │       ├── ...
    ├── resource
    │   ├── vinsfusion_mono
    │   │   ├── 2024-11-15-11-37-15_compressed
    │   │   │   └── monitor_cpu_only.csv
    │   │   ├── ...
    │   └── vinsfusion_stereo
    │       ├── ...
    └── time
        ├── vinsfusion_mono
        │   ├── 2024-11-15-11-37-15_compressed
        │   │   └── vio_time.txt
        │   ├── ...
        └── vinsfusion_stereo
            ├── ...
```

## 4. Trajectory evaluation with [EPICA](https://epic-lab-gwu.github.io/EPIC-Alignment/)
After you get the output pose files, you can evaluate the performance with [EPICA](https://epic-lab-gwu.github.io/EPIC-Alignment/). EPICA is a trajectory alignment and evaluation toolkit. To evaluate ATE and RPE, use the following command:

```bash
# install EPICA
pip install epica

# evaluate ATE and RPE with EPICA, take Euroc MAV dataset machine_hall group for example
epa_ov_error_comparison se3 <Path_to_GT_folder>/euroc_mav/machine_hall <YOUR_DATASET_FOLDER_ON_HOST>/VINS-FUSION_output/euroc_mav/pose 
```
Example ground truth folder structure:

<details>
<summary><u>GT structure</u></summary>

```text
|gt
|-- aqualoc
|   |-- archaeo
|   |   |-- archaeo1
|   |   |   |-- archaeo_sequence_1.txt
|   |   |   |-- ... 
|   |   |   `-- archaeo_sequence_5.txt
|   |   `-- archaeo2
|   |       |-- archaeo_sequence_10.txt
|   |       |-- ...
|   |       `-- archaeo_sequence_9.txt
|   `-- harbor
|       |-- harbor_sequence_1.txt
|       |-- ...
|       `-- harbor_sequence_7.txt
|-- euroc_mav
|   |-- machine_hall
|   |   |-- MH_01_easy.txt
|   |   |-- ...
|   |   `-- MH_05_difficult.txt
|   `-- vicon_room
|       |-- V1_01_easy.txt
|       |-- ...
|       `-- V2_03_difficult.txt
|-- grand_tour
|   |-- group1
|   |   |-- 2024-10-01-11-29-55.txt
|   |   |-- ...
|   |   `-- 2024-11-02-21-12-51.txt
|   |-- group2
|   |   |-- 2024-11-03-07-52-45.txt
|   |   |-- ...
|   |   `-- 2024-11-04-12-55-59.txt
|   |-- group3
|   |   |-- 2024-11-04-13-07-13.txt
|   |   |-- ...
|   |   `-- 2024-11-11-14-29-44.txt
|   |-- group4
|   |   |-- 2024-11-14-11-17-02.txt
|   |   |-- ...
|   |   `-- 2024-11-14-16-04-09.txt
|   |-- group5
|   |   |-- 2024-11-15-10-16-35.txt
|   |   |-- ...
|   |   `-- 2024-11-15-14-14-12.txt
|   |-- group6
|   |   |-- 2024-11-15-14-43-52.txt
|   |   |-- ...
|   |   `-- 2024-11-18-16-59-23.txt
|   `-- group7
|       |-- 2024-11-25-14-57-08.txt
|       |-- ...
|       `-- 2024-12-03-13-26-40.txt
|-- lamaria
|   |-- add
|   |   |-- sequence_1_19.txt
|   |   |-- ...
|   |   `-- sequence_4_11.txt
|   |-- cp
|   |   |-- R_11_5cp.txt
|   |   |-- ...
|   |   `-- R_13_15cp.txt
|   |-- easy
|   |   |-- R_01_easy.txt
|   |   |-- ...
|   |   `-- R_03_easy.txt
|   |-- hard
|   |   |-- R_08_hard.txt
|   |   |-- ...
|   |   `-- R_10_hard.txt
|   `-- medium
|       |-- R_04_medium.txt
|       |-- ...
|       `-- R_07_medium.txt
`-- uzhfpv
    |-- uzhfpv_indoor
    |   |-- indoor_forward_10_snapdragon_with_gt.txt
    |   |-- ...
    |   `-- indoor_forward_9_snapdragon_with_gt.txt
    |-- uzhfpv_indoor_45
    |   |-- indoor_45_12_snapdragon_with_gt.txt
    |   |-- ...
    |   `-- indoor_45_4_snapdragon_with_gt.txt
    |-- uzhfpv_outdoor
    |   |-- outdoor_forward_1_snapdragon_with_gt.txt
    |   |-- ...
    |   `-- outdoor_forward_5_snapdragon_with_gt.txt
    `-- uzhfpv_outdoor_45
        `-- outdoor_45_1_snapdragon_with_gt.txt
```
</details>

## 5. Acknowledgement
Orginal [VINS-Fusion](https://github.com/HKUST-Aerial-Robotics/VINS-Fusion) codebase is developed by [Tong Qin](http://www.qintonguav.com), Shaozu Cao, Jie Pan, [Peiliang Li](https://peiliangli.github.io/), and [Shaojie Shen](http://www.ece.ust.hk/ece.php/profile/facultydetail/eeshaojie) from the [Aerial Robotics Group](http://uav.ust.hk/), [HKUST](https://www.ust.hk/). And the trajectory evaluation with EPICA is developed by [EPIC Lab](https://epic-lab-gwu.github.io/EPIC-Alignment/) from George Washington University. We thank the original authors and datasets providers for their great work and open-sourcing the code.
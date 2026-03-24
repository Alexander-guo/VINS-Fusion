/*******************************************************
 * Copyright (C) 2019, Aerial Robotics Group, Hong Kong University of Science and Technology
 * 
 * This file is part of VINS.
 * 
 * Licensed under the GNU General Public License v3.0;
 * you may not use this file except in compliance with the License.
 *
 * Author: Qin Tong (qintonguav@gmail.com)
 *******************************************************/

#include <stdio.h>
#include <queue>
#include <map>
#include <thread>
#include <mutex>
#include <ros/ros.h>
#include <cv_bridge/cv_bridge.h>
#include <sensor_msgs/CompressedImage.h>
#include <opencv2/opencv.hpp>
#include "estimator/estimator.h"
#include "estimator/parameters.h"
#include "utility/visualization.h"

Estimator estimator;

queue<sensor_msgs::ImuConstPtr> imu_buf;
queue<sensor_msgs::PointCloudConstPtr> feature_buf;
struct ImageData
{
    double stamp;
    cv::Mat image;
};
queue<ImageData> img0_buf;
queue<ImageData> img1_buf;
std::mutex m_buf;

cv::Mat getImageFromMsg(const sensor_msgs::ImageConstPtr &img_msg);
cv::Mat getImageFromMsg(const sensor_msgs::CompressedImageConstPtr &img_msg);


void img0_callback(const sensor_msgs::ImageConstPtr &img_msg)
{
    cv::Mat img = getImageFromMsg(img_msg);
    if (img.empty())
        return;

    m_buf.lock();
    img0_buf.push({img_msg->header.stamp.toSec(), img});
    m_buf.unlock();
}

void img1_callback(const sensor_msgs::ImageConstPtr &img_msg)
{
    cv::Mat img = getImageFromMsg(img_msg);
    if (img.empty())
        return;

    m_buf.lock();
    img1_buf.push({img_msg->header.stamp.toSec(), img});
    m_buf.unlock();
}


cv::Mat getImageFromMsg(const sensor_msgs::ImageConstPtr &img_msg)
{
    cv_bridge::CvImageConstPtr ptr;
    if (img_msg->encoding == "8UC1")
    {
        sensor_msgs::Image img;
        img.header = img_msg->header;
        img.height = img_msg->height;
        img.width = img_msg->width;
        img.is_bigendian = img_msg->is_bigendian;
        img.step = img_msg->step;
        img.data = img_msg->data;
        img.encoding = "mono8";
        ptr = cv_bridge::toCvCopy(img, sensor_msgs::image_encodings::MONO8);
    }
    else
        ptr = cv_bridge::toCvCopy(img_msg, sensor_msgs::image_encodings::MONO8);

    cv::Mat img = ptr->image.clone();
    return img;
}

cv::Mat getImageFromMsg(const sensor_msgs::CompressedImageConstPtr &img_msg)
{
    cv::Mat compressed(1, img_msg->data.size(), CV_8UC1, const_cast<uchar *>(img_msg->data.data()));
    cv::Mat decoded = cv::imdecode(compressed, cv::IMREAD_UNCHANGED);

    if (decoded.empty())
    {
        ROS_WARN("failed to decode compressed image at time %f", img_msg->header.stamp.toSec());
        return cv::Mat();
    }

    cv::Mat gray;
    if (decoded.channels() == 1)
        gray = decoded;
    else if (decoded.channels() == 3)
        cv::cvtColor(decoded, gray, cv::COLOR_BGR2GRAY);
    else if (decoded.channels() == 4)
        cv::cvtColor(decoded, gray, cv::COLOR_BGRA2GRAY);
    else
    {
        ROS_WARN("unsupported channel count in compressed image: %d", decoded.channels());
        return cv::Mat();
    }

    if (gray.type() == CV_8UC1)
        return gray;

    cv::Mat gray8;
    if (gray.depth() == CV_16U)
        gray.convertTo(gray8, CV_8UC1, 1.0 / 256.0);
    else
        gray.convertTo(gray8, CV_8UC1);
    return gray8;
}

void img0_compressed_callback(const sensor_msgs::CompressedImageConstPtr &img_msg)
{
    cv::Mat img = getImageFromMsg(img_msg);
    if (img.empty())
        return;

    m_buf.lock();
    img0_buf.push({img_msg->header.stamp.toSec(), img});
    m_buf.unlock();
}

void img1_compressed_callback(const sensor_msgs::CompressedImageConstPtr &img_msg)
{
    cv::Mat img = getImageFromMsg(img_msg);
    if (img.empty())
        return;

    m_buf.lock();
    img1_buf.push({img_msg->header.stamp.toSec(), img});
    m_buf.unlock();
}

// extract images with same timestamp from two topics
void sync_process()
{
    while(1)
    {
        if(STEREO)
        {
            cv::Mat image0, image1;
            double time = 0;
            m_buf.lock();
            if (!img0_buf.empty() && !img1_buf.empty())
            {
                double time0 = img0_buf.front().stamp;
                double time1 = img1_buf.front().stamp;
                // 0.003s sync tolerance
                if(time0 < time1 - 0.003)
                {
                    img0_buf.pop();
                    printf("throw img0\n");
                }
                else if(time0 > time1 + 0.003)
                {
                    img1_buf.pop();
                    printf("throw img1\n");
                }
                else
                {
                    time = img0_buf.front().stamp;
                    image0 = img0_buf.front().image;
                    img0_buf.pop();
                    image1 = img1_buf.front().image;
                    img1_buf.pop();
                    //printf("find img0 and img1\n");
                }
            }
            m_buf.unlock();
            if(!image0.empty())
                estimator.inputImage(time, image0, image1);
        }
        else
        {
            cv::Mat image;
            double time = 0;
            m_buf.lock();
            if(!img0_buf.empty())
            {
                time = img0_buf.front().stamp;
                image = img0_buf.front().image;
                img0_buf.pop();
            }
            m_buf.unlock();
            if(!image.empty())
                estimator.inputImage(time, image);
        }

        std::chrono::milliseconds dura(2);
        std::this_thread::sleep_for(dura);
    }
}


void imu_callback(const sensor_msgs::ImuConstPtr &imu_msg)
{
    double t = imu_msg->header.stamp.toSec();
    double dx = imu_msg->linear_acceleration.x;
    double dy = imu_msg->linear_acceleration.y;
    double dz = imu_msg->linear_acceleration.z;
    double rx = imu_msg->angular_velocity.x;
    double ry = imu_msg->angular_velocity.y;
    double rz = imu_msg->angular_velocity.z;
    Vector3d acc(dx, dy, dz);
    Vector3d gyr(rx, ry, rz);
    estimator.inputIMU(t, acc, gyr);
    return;
}


void feature_callback(const sensor_msgs::PointCloudConstPtr &feature_msg)
{
    map<int, vector<pair<int, Eigen::Matrix<double, 7, 1>>>> featureFrame;
    for (unsigned int i = 0; i < feature_msg->points.size(); i++)
    {
        int feature_id = feature_msg->channels[0].values[i];
        int camera_id = feature_msg->channels[1].values[i];
        double x = feature_msg->points[i].x;
        double y = feature_msg->points[i].y;
        double z = feature_msg->points[i].z;
        double p_u = feature_msg->channels[2].values[i];
        double p_v = feature_msg->channels[3].values[i];
        double velocity_x = feature_msg->channels[4].values[i];
        double velocity_y = feature_msg->channels[5].values[i];
        if(feature_msg->channels.size() > 5)
        {
            double gx = feature_msg->channels[6].values[i];
            double gy = feature_msg->channels[7].values[i];
            double gz = feature_msg->channels[8].values[i];
            pts_gt[feature_id] = Eigen::Vector3d(gx, gy, gz);
            //printf("receive pts gt %d %f %f %f\n", feature_id, gx, gy, gz);
        }
        ROS_ASSERT(z == 1);
        Eigen::Matrix<double, 7, 1> xyz_uv_velocity;
        xyz_uv_velocity << x, y, z, p_u, p_v, velocity_x, velocity_y;
        featureFrame[feature_id].emplace_back(camera_id,  xyz_uv_velocity);
    }
    double t = feature_msg->header.stamp.toSec();
    estimator.inputFeature(t, featureFrame);
    return;
}

void restart_callback(const std_msgs::BoolConstPtr &restart_msg)
{
    if (restart_msg->data == true)
    {
        ROS_WARN("restart the estimator!");
        estimator.clearState();
        estimator.setParameter();
    }
    return;
}

void imu_switch_callback(const std_msgs::BoolConstPtr &switch_msg)
{
    if (switch_msg->data == true)
    {
        //ROS_WARN("use IMU!");
        estimator.changeSensorType(1, STEREO);
    }
    else
    {
        //ROS_WARN("disable IMU!");
        estimator.changeSensorType(0, STEREO);
    }
    return;
}

void cam_switch_callback(const std_msgs::BoolConstPtr &switch_msg)
{
    if (switch_msg->data == true)
    {
        //ROS_WARN("use stereo!");
        estimator.changeSensorType(USE_IMU, 1);
    }
    else
    {
        //ROS_WARN("use mono camera (left)!");
        estimator.changeSensorType(USE_IMU, 0);
    }
    return;
}

int main(int argc, char **argv)
{
    ros::init(argc, argv, "vins_estimator");
    ros::NodeHandle n("~");
    ros::console::set_logger_level(ROSCONSOLE_DEFAULT_NAME, ros::console::levels::Info);

    if(argc != 2)
    {
        printf("please intput: rosrun vins vins_node [config file] \n"
               "for example: rosrun vins vins_node "
               "~/catkin_ws/src/VINS-Fusion/config/euroc/euroc_stereo_imu_config.yaml \n");
        return 1;
    }

    string config_file = argv[1];
    printf("config_file: %s\n", argv[1]);

    readParameters(config_file);
    estimator.setParameter();

#ifdef EIGEN_DONT_PARALLELIZE
    ROS_DEBUG("EIGEN_DONT_PARALLELIZE");
#endif

    ROS_WARN("waiting for image and imu...");

    registerPub(n);

    ros::Subscriber sub_imu;
    if(USE_IMU)
    {
        sub_imu = n.subscribe(IMU_TOPIC, 2000, imu_callback, ros::TransportHints().tcpNoDelay());
    }
    ros::Subscriber sub_feature = n.subscribe("/feature_tracker/feature", 2000, feature_callback);
    bool img0_is_compressed = IMAGE0_TOPIC.find("compressed") != string::npos;
    ros::Subscriber sub_img0;
    if(img0_is_compressed)
    {
        ROS_INFO("subscribe compressed image topic: %s", IMAGE0_TOPIC.c_str());
        sub_img0 = n.subscribe(IMAGE0_TOPIC, 100, img0_compressed_callback);
    }
    else
    {
        sub_img0 = n.subscribe(IMAGE0_TOPIC, 100, img0_callback);
    }
    ros::Subscriber sub_img1;
    if(STEREO)
    {
        bool img1_is_compressed = IMAGE1_TOPIC.find("compressed") != string::npos;
        if(img1_is_compressed)
        {
            ROS_INFO("subscribe compressed image topic: %s", IMAGE1_TOPIC.c_str());
            sub_img1 = n.subscribe(IMAGE1_TOPIC, 100, img1_compressed_callback);
        }
        else
        {
            sub_img1 = n.subscribe(IMAGE1_TOPIC, 100, img1_callback);
        }
    }
    ros::Subscriber sub_restart = n.subscribe("/vins_restart", 100, restart_callback);
    ros::Subscriber sub_imu_switch = n.subscribe("/vins_imu_switch", 100, imu_switch_callback);
    ros::Subscriber sub_cam_switch = n.subscribe("/vins_cam_switch", 100, cam_switch_callback);

    std::thread sync_thread{sync_process};
    ros::spin();

    return 0;
}

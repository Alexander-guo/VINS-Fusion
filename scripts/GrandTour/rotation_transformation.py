import numpy as np
from scipy.spatial.transform import Rotation as R
from argparse import ArgumentParser


def quaternion_to_rotation_matrix(quat):
    # Quaternion from the user (w, x, y, z)
    # Scipy uses [x, y, z, w] format

    quat_xyzw = [quat[1], quat[2], quat[3], quat[0]]
    r = R.from_quat(quat_xyzw)
    rotation_matrix = r.as_matrix()
    return rotation_matrix

if __name__ == "__main__":

    np.set_printoptions(suppress=True, precision=7) 
     
    # cam_T_boxbase [w, x, y, z]
    # cam0: front_left, cam1: front_right in their metadata
    quad_cam0_boxbase = [0.5368758638762299, -0.45974498896225247, -0.45019665401233916, -0.5456389141431761]
    translation_cam0_boxbase = [0.10008743117500188, -0.005044106160423112, -0.3759478344493785]
    
    quad_cam1_boxbase = [0.5415552717416523, -0.45428021832487614, -0.45594501981218066, -0.5407971059426985]
    translation_cam1_boxbase = [-0.008591409149567839, -0.004939215486247553, -0.3747769505103547]
    
    quad_imu_boxbase = [0.9992675697949326, -0.00720142304148732, -0.036738890418011295, -0.007919431365965667]
    translation_imu_boxbase = [-0.3022307436356707, 0.061798150722505, -0.08410765585489798]
    
    rot_cam0_boxbase = quaternion_to_rotation_matrix(quad_cam0_boxbase)
    rot_cam1_boxbase = quaternion_to_rotation_matrix(quad_cam1_boxbase)
    rot_imu_boxbase = quaternion_to_rotation_matrix(quad_imu_boxbase)
    print(f"Rotation matrix from cam0 frame to box base frame (cam0_R_boxbase):\n{rot_cam0_boxbase}")
    print(f"Rotation matrix from cam1 frame to box base frame (cam1_R_boxbase):\n{rot_cam1_boxbase}")
    print(f"Rotation matrix from IMU frame to box base frame (imu_R_boxbase):\n{rot_imu_boxbase}")

    H_cam0_boxbase = np.eye(4)
    H_cam0_boxbase[:3, :3] = rot_cam0_boxbase
    H_cam0_boxbase[:3, 3] = translation_cam0_boxbase
    H_boxbase_cam0 = np.linalg.inv(H_cam0_boxbase)  
    
    H_cam1_boxbase = np.eye(4)
    H_cam1_boxbase[:3, :3] = rot_cam1_boxbase
    H_cam1_boxbase[:3, 3] = translation_cam1_boxbase
    H_boxbase_cam1 = np.linalg.inv(H_cam1_boxbase)  
    
    H_imu_boxbase = np.eye(4)
    H_imu_boxbase[:3, :3] = rot_imu_boxbase
    H_imu_boxbase[:3, 3] = translation_imu_boxbase
    # H_boxbase_imu = np.linalg.inv(H_imu_boxbase)  

    H_imu_cam0 = H_imu_boxbase @ H_boxbase_cam0
    H_imu_cam1 = H_imu_boxbase @ H_boxbase_cam1
    print("Transformation from Imu to Camera 0 (imu_T_cam0):")
    print(H_imu_cam0)
    print("\nTransformation from Imu to Camera 1 (imu_T_cam1):")
    print(H_imu_cam1) 
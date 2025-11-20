// opencv_compat.h - place in include path before source compilation
#ifndef OPENCV_COMPAT_H
#define OPENCV_COMPAT_H

#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>

#ifndef CV_GRAY2RGB
#define CV_GRAY2RGB cv::COLOR_GRAY2RGB
#endif
#ifndef CV_GRAY2BGR
#define CV_GRAY2BGR cv::COLOR_GRAY2BGR
#endif
#ifndef CV_BGR2GRAY
#define CV_BGR2GRAY cv::COLOR_BGR2GRAY
#endif
#ifndef CV_AA
#define CV_AA cv::LINE_AA
#endif

// Calib flags
#ifndef CV_CALIB_CB_ADAPTIVE_THRESH
#define CV_CALIB_CB_ADAPTIVE_THRESH cv::CALIB_CB_ADAPTIVE_THRESH
#endif
#ifndef CV_CALIB_CB_NORMALIZE_IMAGE
#define CV_CALIB_CB_NORMALIZE_IMAGE cv::CALIB_CB_NORMALIZE_IMAGE
#endif
#ifndef CV_CALIB_CB_FILTER_QUADS
#define CV_CALIB_CB_FILTER_QUADS cv::CALIB_CB_FILTER_QUADS
#endif
#ifndef CV_CALIB_CB_FAST_CHECK
#define CV_CALIB_CB_FAST_CHECK cv::CALIB_CB_FAST_CHECK
#endif

// Thresholding / adaptive methods
#ifndef CV_ADAPTIVE_THRESH_MEAN_C
#define CV_ADAPTIVE_THRESH_MEAN_C cv::ADAPTIVE_THRESH_MEAN_C
#endif
#ifndef CV_THRESH_BINARY
#define CV_THRESH_BINARY cv::THRESH_BINARY
#endif
#ifndef CV_THRESH_BINARY_INV
#define CV_THRESH_BINARY_INV cv::THRESH_BINARY_INV
#endif

// Contours / retrieval modes
#ifndef CV_RETR_CCOMP
#define CV_RETR_CCOMP cv::RETR_CCOMP
#endif
#ifndef CV_CHAIN_APPROX_SIMPLE
#define CV_CHAIN_APPROX_SIMPLE cv::CHAIN_APPROX_SIMPLE
#endif

// Morphology shapes
#ifndef CV_SHAPE_CROSS
#define CV_SHAPE_CROSS cv::MORPH_CROSS
#endif
#ifndef CV_SHAPE_RECT
#define CV_SHAPE_RECT cv::MORPH_RECT
#endif

// Terminal criteria
#ifndef CV_TERMCRIT_EPS
#define CV_TERMCRIT_EPS cv::TermCriteria::EPS
#endif
#ifndef CV_TERMCRIT_ITER
#define CV_TERMCRIT_ITER cv::TermCriteria::COUNT
#endif

#endif // OPENCV_COMPAT_H
#!/usr/bin/env python3
# pyright: reportMissingImports=false
"""Rotate selected image topics in a ROS bag and write to a new bag.

Supports:
- ROS1 bags (.bag files) via `rosbag`
- ROS2 bags (directory containing metadata.yaml) via `rosbag2_py`

Example:
	python rosbags_image_flipping.py /path/to/bag \
	  --image-topics /cam0/image_raw /cam1/image_raw \
	  --degrees 90 180
"""

from __future__ import annotations

import argparse
import copy
from pathlib import Path
from typing import Dict, List, Tuple

import cv2
import numpy as np
from tqdm import tqdm


VALID_DEGREES = {90, 180, 270}


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(
		description=(
			"Rotate one or more image topics in a ROS1/ROS2 bag and save to a new bag. "
			"Rotation is clockwise and limited to 90/180/270 degrees."
		)
	)
	parser.add_argument("bag_path", help="Input ROS1 .bag file or ROS2 bag directory")
	parser.add_argument(
		"--image-topics",
		nargs="+",
		required=True,
		help="Image topics to rotate",
	)
	parser.add_argument(
		"--degrees",
		nargs="+",
		type=int,
		required=True,
		help="Clockwise rotation degrees (each must be one of: 90, 180, 270)",
	)
	parser.add_argument(
		"--output",
		default=None,
		help="Output bag path (default: auto-generated from input)",
	)
	parser.add_argument(
		"--overwrite",
		action="store_true",
		help="Overwrite output if it already exists",
	)
	parser.add_argument(
		"--ros1-compression",
		choices=["auto", "none", "bz2", "lz4"],
		default="auto",
		help=(
			"Compression for ROS1 output bag. 'auto' tries to match input bag dominant "
			"compression; others force the selected mode."
		),
	)
	parser.add_argument(
		"--jpeg-quality",
		type=int,
		default=80,
		help=(
			"JPEG quality (1-100) when rotating sensor_msgs/CompressedImage encoded as JPEG. "
			"Lower value gives smaller bags. Default: 80"
		),
	)
	return parser.parse_args()


def build_topic_degree_map(topics: List[str], degrees: List[int]) -> Dict[str, int]:
	if not topics:
		raise ValueError("--image-topics cannot be empty")

	invalid = [d for d in degrees if d not in VALID_DEGREES]
	if invalid:
		raise ValueError(f"Invalid degrees {invalid}. Only 90, 180, 270 are supported.")

	if len(degrees) == 1:
		return {topic: degrees[0] for topic in topics}

	if len(degrees) != len(topics):
		raise ValueError(
			"--degrees must contain either one value (applied to all topics) "
			"or exactly the same number of values as --image-topics"
		)

	return dict(zip(topics, degrees))


def infer_bag_kind(bag_path: Path) -> str:
	if bag_path.is_file() and bag_path.suffix == ".bag":
		return "ros1"
	if bag_path.is_dir() and (bag_path / "metadata.yaml").exists():
		return "ros2"
	raise ValueError(
		f"Cannot determine bag type for '{bag_path}'. "
		"Expected ROS1 .bag file or ROS2 directory with metadata.yaml"
	)


def default_output_path(input_path: Path, bag_kind: str) -> Path:
	if bag_kind == "ros1":
		return input_path.with_name(f"{input_path.stem}_flipped.bag")
	return input_path.with_name(f"{input_path.name}_flipped")


def get_encoding_info(encoding: str) -> Tuple[np.dtype, int]:
	enc = encoding.lower()

	mapping = {
		"mono8": (np.uint8, 1),
		"8uc1": (np.uint8, 1),
		"8sc1": (np.int8, 1),
		"mono16": (np.uint16, 1),
		"16uc1": (np.uint16, 1),
		"16sc1": (np.int16, 1),
		"32fc1": (np.float32, 1),
		"32sc1": (np.int32, 1),
		"rgb8": (np.uint8, 3),
		"bgr8": (np.uint8, 3),
		"rgba8": (np.uint8, 4),
		"bgra8": (np.uint8, 4),
		"rgb16": (np.uint16, 3),
		"bgr16": (np.uint16, 3),
		"rgba16": (np.uint16, 4),
		"bgra16": (np.uint16, 4),
	}

	if enc in mapping:
		return mapping[enc]

	# Generic encodings like 8UC3, 16SC4, 32FC1 ...
	import re

	match = re.fullmatch(r"(8|16|32)(u|s|f)c(\d+)", enc)
	if match:
		bits, dtype_code, channels_s = match.groups()
		channels = int(channels_s)

		if bits == "8" and dtype_code == "u":
			dtype = np.uint8
		elif bits == "8" and dtype_code == "s":
			dtype = np.int8
		elif bits == "16" and dtype_code == "u":
			dtype = np.uint16
		elif bits == "16" and dtype_code == "s":
			dtype = np.int16
		elif bits == "32" and dtype_code == "u":
			dtype = np.uint32
		elif bits == "32" and dtype_code == "s":
			dtype = np.int32
		elif bits == "32" and dtype_code == "f":
			dtype = np.float32
		else:
			raise ValueError(f"Unsupported image encoding: {encoding}")
		return dtype, channels

	raise ValueError(f"Unsupported image encoding: {encoding}")


def rotate_ndarray_clockwise(arr: np.ndarray, degrees: int) -> np.ndarray:
	if degrees == 90:
		return cv2.rotate(arr, cv2.ROTATE_90_CLOCKWISE)
	if degrees == 180:
		return cv2.rotate(arr, cv2.ROTATE_180)
	if degrees == 270:
		return cv2.rotate(arr, cv2.ROTATE_90_COUNTERCLOCKWISE)
	raise ValueError(f"Unsupported degrees: {degrees}")


def rotate_sensor_image_msg_inplace(msg, degrees: int) -> None:
	dtype, channels = get_encoding_info(msg.encoding)

	height = int(msg.height)
	width = int(msg.width)
	itemsize = np.dtype(dtype).itemsize

	row_elems = int(msg.step) // itemsize
	raw = np.frombuffer(bytes(msg.data), dtype=dtype)
	if raw.size < height * row_elems:
		raise ValueError("Image data is smaller than expected from height/step")
	raw = raw[: height * row_elems].reshape(height, row_elems)

	if channels == 1:
		img = raw[:, :width]
	else:
		img = raw[:, : width * channels].reshape(height, width, channels)

	rotated = rotate_ndarray_clockwise(img, degrees)
	rotated = np.ascontiguousarray(rotated)

	msg.height = int(rotated.shape[0])
	msg.width = int(rotated.shape[1])
	msg.step = int(rotated.shape[1] * channels * itemsize)
	msg.data = rotated.tobytes()


def rotate_compressed_image_msg_inplace(msg, degrees: int, jpeg_quality: int) -> None:
	encoded = np.frombuffer(bytes(msg.data), dtype=np.uint8)
	decoded = cv2.imdecode(encoded, cv2.IMREAD_UNCHANGED)
	if decoded is None:
		raise ValueError("Failed to decode compressed image")

	rotated = rotate_ndarray_clockwise(decoded, degrees)

	fmt = (msg.format or "").lower()
	is_png = "png" in fmt
	ext = ".png" if is_png else ".jpg"
	params = []
	if not is_png:
		params = [int(cv2.IMWRITE_JPEG_QUALITY), int(jpeg_quality)]
	ok, out_buf = cv2.imencode(ext, rotated, params)
	if not ok:
		raise ValueError("Failed to encode rotated compressed image")

	msg.data = out_buf.tobytes()


def maybe_rotate_msg(topic: str, msg, topic_degree: Dict[str, int], jpeg_quality: int) -> bool:
	if topic not in topic_degree:
		return False

	degrees = topic_degree[topic]
	msg_type = getattr(msg, "_type", None)
	if msg_type is None:
		msg_type = f"{msg.__class__.__module__.replace('.', '/')}/{msg.__class__.__name__}"

	if "sensor_msgs/Image" in msg_type:
		rotate_sensor_image_msg_inplace(msg, degrees)
		return True
	if "sensor_msgs/CompressedImage" in msg_type:
		rotate_compressed_image_msg_inplace(msg, degrees, jpeg_quality=jpeg_quality)
		return True
	return False


def detect_ros1_input_compression(inbag) -> str:
	compression_sizes = {"none": 0, "bz2": 0, "lz4": 0}
	try:
		for comp, _uncompressed, compressed in inbag.get_compression_info():
			comp_key = str(comp).lower()
			if comp_key in compression_sizes:
				compression_sizes[comp_key] += int(compressed)
	except Exception:
		return "none"

	best = max(compression_sizes, key=compression_sizes.get)
	if compression_sizes[best] <= 0:
		return "none"
	return best


def process_ros1(
	in_path: Path,
	out_path: Path,
	topic_degree: Dict[str, int],
	ros1_compression: str,
	jpeg_quality: int,
) -> None:
	try:
		import rosbag
	except ImportError as exc:
		raise RuntimeError(
			"ROS1 processing import failed. Ensure ROS1 is sourced and required Python deps are "
			f"installed in the current interpreter (e.g. PyYAML). Original error: {exc}"
		) from exc

	rotated_count = 0
	with rosbag.Bag(str(in_path), "r") as inbag:
		out_compression = ros1_compression
		if ros1_compression == "auto":
			out_compression = detect_ros1_input_compression(inbag)

		with rosbag.Bag(str(out_path), "w", compression=out_compression) as outbag:
			total_msgs = inbag.get_message_count()
			with tqdm(
				total=total_msgs,
				desc=f"ROS1 messages ({out_compression})",
				unit="msg",
			) as pbar:
				for topic, msg, stamp in inbag.read_messages():
					out_msg = msg
					if topic in topic_degree:
						out_msg = copy.deepcopy(msg)
						if maybe_rotate_msg(topic, out_msg, topic_degree, jpeg_quality=jpeg_quality):
							rotated_count += 1
					outbag.write(topic, out_msg, stamp)
					pbar.update(1)

	print(f"[ROS1] Done. Rotated {rotated_count} frame(s). Output: {out_path}")


def process_ros2(
	in_path: Path,
	out_path: Path,
	topic_degree: Dict[str, int],
	jpeg_quality: int,
) -> None:
	try:
		import rosbag2_py
		from rclpy.serialization import deserialize_message, serialize_message
		from rosidl_runtime_py.utilities import get_message
	except ImportError as exc:
		raise RuntimeError(
			"ROS2 processing import failed. Ensure ROS2 is sourced and rosbag2/rclpy Python deps are "
			f"available in the current interpreter. Original error: {exc}"
		) from exc

	reader = rosbag2_py.SequentialReader()
	reader.open(
		rosbag2_py.StorageOptions(uri=str(in_path), storage_id="sqlite3"),
		rosbag2_py.ConverterOptions(
			input_serialization_format="cdr",
			output_serialization_format="cdr",
		),
	)

	topic_meta = reader.get_all_topics_and_types()
	topic_to_type = {t.name: t.type for t in topic_meta}
	topic_to_cls = {name: get_message(type_name) for name, type_name in topic_to_type.items()}

	writer = rosbag2_py.SequentialWriter()
	writer.open(
		rosbag2_py.StorageOptions(uri=str(out_path), storage_id="sqlite3"),
		rosbag2_py.ConverterOptions(
			input_serialization_format="cdr",
			output_serialization_format="cdr",
		),
	)

	for meta in topic_meta:
		writer.create_topic(meta)

	rotated_count = 0
	with tqdm(desc="ROS2 messages", unit="msg") as pbar:
		while reader.has_next():
			topic, raw, timestamp = reader.read_next()
			if topic in topic_degree and topic in topic_to_cls:
				cls = topic_to_cls[topic]
				msg = deserialize_message(raw, cls)
				if maybe_rotate_msg(topic, msg, topic_degree, jpeg_quality=jpeg_quality):
					raw = serialize_message(msg)
					rotated_count += 1
			writer.write(topic, raw, timestamp)
			pbar.update(1)

	print(f"[ROS2] Done. Rotated {rotated_count} frame(s). Output: {out_path}")


def main() -> None:
	args = parse_args()
	if not (1 <= args.jpeg_quality <= 100):
		raise ValueError("--jpeg-quality must be in range [1, 100]")

	bag_path = Path(args.bag_path).expanduser().resolve()
	topic_degree = build_topic_degree_map(args.image_topics, args.degrees)

	bag_kind = infer_bag_kind(bag_path)
	out_path = Path(args.output).expanduser().resolve() if args.output else default_output_path(bag_path, bag_kind)

	if out_path.exists():
		if not args.overwrite:
			raise FileExistsError(
				f"Output path already exists: {out_path}. Use --overwrite to replace it."
			)
		if out_path.is_file():
			out_path.unlink()
		else:
			import shutil

			shutil.rmtree(out_path)

	if bag_kind == "ros1":
		process_ros1(
			bag_path,
			out_path,
			topic_degree,
			ros1_compression=args.ros1_compression,
			jpeg_quality=args.jpeg_quality,
		)
	else:
		process_ros2(
			bag_path,
			out_path,
			topic_degree,
			jpeg_quality=args.jpeg_quality,
		)


if __name__ == "__main__":
	main()


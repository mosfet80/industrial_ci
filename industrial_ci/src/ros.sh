#!/bin/bash

# Copyright (c) 2015, Isaac I. Y. Saito
# Copyright (c) 2017, Mathias Lüdtke
# All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function  _ros1_defaults {
    export OS_CODE_NAME=${OS_CODE_NAME:-$1}
    export ROS1_DISTRO=${ROS1_DISTRO:-$ROS_DISTRO}
    export BUILDER=${BUILDER:-catkin_tools}
    export ROS_VERSION=1
    export ROS_VERSION_EOL=false
    export ROS_VERSION_FINAL="final"
    export ROS_PYTHON_VERSION=${ROS_PYTHON_VERSION:-2}
}

function  _ros2_defaults {
    export OS_CODE_NAME=${OS_CODE_NAME:-$1}
    export ROS2_DISTRO=${ROS2_DISTRO:-$ROS_DISTRO}
    export BUILDER=${BUILDER:-colcon}
    export ROS_VERSION=2
    export ROS_VERSION_EOL=false
    export ROS_VERSION_FINAL="final"
    export ROS_PYTHON_VERSION=3
}

function _ros_is_eol {
    export ROS_VERSION_EOL=true
    export ROSDISTRO_INDEX_VERSION=${ROSDISTRO_INDEX_VERSION:-$1}
}

function _set_ros_defaults {
    case "$ROS_DISTRO" in
    "indigo"|"jade")
        _ros1_defaults "trusty"
        _ros_is_eol "kinetic/2021-05-11"
        export _ROS_KEYRING=/etc/apt/trusted.gpg.d/ros-archive-keyring.gpg # signed-by is not supported
        ;;
    "kinetic")
        _ros1_defaults "xenial"
        _ros_is_eol "kinetic/2021-05-11"
        ;;
    "lunar")
        _ros1_defaults "xenial"
        _ros_is_eol "kinetic/2021-05-11"
        ;;
    "melodic")
        _ros1_defaults "bionic"
        _ros_is_eol "melodic/2023-06-27"
        ;;
    "noetic")
        _ros1_defaults "focal"
        export ROS_PYTHON_VERSION=3
        if [ "$OS_NAME" = "debian" ]; then
            _ros_is_eol "noetic/2023-03-02"
            export ROS_VERSION_FINAL_DEBIAN=true
        else
            _ros_is_eol "noetic/2025-05-29"
        fi
        ;;
    "ardent")
        _ros2_defaults "xenial"
        _ros_is_eol "dashing/2021-06-10"
        ;;
    "bouncy"|"crystal")
        _ros2_defaults "bionic"
        _ros_is_eol "dashing/2021-06-10"
        ;;
    "dashing")
        _ros2_defaults "bionic"
        _ros_is_eol "dashing/2021-06-10"
        ;;
    "eloquent")
        _ros2_defaults "bionic"
        _ros_is_eol "eloquent/2020-12-12"
        ;;
    "foxy")
        _ros2_defaults "focal"
        _ros_is_eol "foxy/2023-06-20"
        ;;
    "galactic")
        _ros2_defaults "focal"
        _ros_is_eol "galactic/2022-12-09"
        ;;
    "humble")
        _ros2_defaults "jammy"
        ;;
    "iron")
        _ros2_defaults "jammy"
        _ros_is_eol "iron/2024-12-04"
        ;;
    "jazzy")
        _ros2_defaults "noble"
        ;;
    "kilted")
        _ros2_defaults "noble"
        ;;
    "rolling")
        _ros2_defaults "noble"
        if [ "$OS_CODE_NAME" == "jammy" ]; then
            if [ -z "$ROSDISTRO_INDEX_VERSION" ]; then
                ici_warn "Pinning rolling to latest support version on jammy: 2024-02-28"
                export ROSDISTRO_INDEX_VERSION=rolling/2024-02-28
            fi
        fi
        ;;
    "false")
        unset ROS_DISTRO
        ;;
    *)
        ici_error "ROS_DISTRO '$ROS_DISTRO' is not supported"
        ;;
    esac

    if [ "$ROS_PYTHON_VERSION" = 2 ]; then
        export PYTHON_VERSION_NAME=python
    elif [ "$ROS_PYTHON_VERSION" = 3 ]; then
        export PYTHON_VERSION_NAME=python3
    fi

}

function _use_snapshot() {
    local osname="ubuntu"
    if [ "$1" = "$ROS_VERSION_FINAL" ] && [ "${ROS_VERSION_FINAL_DEBIAN:-false}" = true ]; then
        osname="debian"
    fi
    export ROS_REPOSITORY_PATH="http://snapshots.ros.org/${ROS_DISTRO?ROS_DISTRO needs to be set}/$1/$osname"
    export ROS_REPOSITORY_KEY="$ICI_SRC_PATH/keys/snapshots.asc"
}

function _use_repo_or_final_snapshot() {
    if [ "$ROS_VERSION_EOL" = true ]; then
        if [ "$ROS_REPO" != "testing" ]; then
            ici_warn "'$ROS_DISTRO' is in end-of-life state, ROS_REPO='$ROS_REPO' is superfluous"
        fi
        if [ -n "$ROS_VERSION_FINAL" ]; then
            _use_snapshot "$ROS_VERSION_FINAL"
            return
        fi
    fi
    export ROS_REPOSITORY_PATH="$1"
    if [ "${ROS_REPO}" = "ros-shadow-fixed" ]; then
        ici_warn "ROS_REPO='ros-shadow-fixed' was renamed to ROS_REPO='testing'"
    fi
}

function _get_prefix() {
    if [ "$ROS_VERSION" -eq 2 ]; then
        echo ros2
    else
        echo ros
    fi
}

function ici_set_ros_repository_path {
    local current_repository_path=$1; shift
    if [ -z "${ROS_REPOSITORY_PATH}" ]; then
        case "$ROS_REPO" in
        "building")
            _use_repo_or_final_snapshot "http://repositories.ros.org/ubuntu/building/"
            ;;
        "main")
            _use_repo_or_final_snapshot "http://packages.ros.org/$(_get_prefix)/ubuntu"
            ;;
        "ros")
            if [ "$ROS_VERSION" -eq 2 ]; then
                ici_warn "ROS_REPO=ros would select the ROS1 repository, please use ROS_REPO=main"
            fi
            _use_repo_or_final_snapshot "http://packages.ros.org/$(_get_prefix)/ubuntu"
            ;;
        "ros1")
            _use_repo_or_final_snapshot "http://packages.ros.org/ros/ubuntu"
            ;;
        "ros2")
            _use_repo_or_final_snapshot "http://packages.ros.org/ros2/ubuntu"
            ;;
        "")
            if [ -n "$current_repository_path" ]; then
                export ROS_REPOSITORY_PATH=$current_repository_path
                return
            fi
            ici_warn "Using default ROS_REPO=testing"
            export ROS_REPO=testing
            ;&
        "testing")
            _use_repo_or_final_snapshot "http://packages.ros.org/$(_get_prefix)-testing/ubuntu"
            ;;
        "ros-shadow-fixed"|"ros-testing")
            if [ "$ROS_VERSION" -eq 2 ]; then
                ici_warn "ROS_REPO=$ROS_REPO would select the ROS1 repository, please use ROS_REPO=testing"
            fi
            _use_repo_or_final_snapshot "http://packages.ros.org/$(_get_prefix)-testing/ubuntu"
            ;;
        "ros1-testing")
            _use_repo_or_final_snapshot "http://packages.ros.org/ros-testing/ubuntu"
            ;;
        "ros2-testing")
            _use_repo_or_final_snapshot "http://packages.ros.org/ros2-testing/ubuntu"
            ;;
        "final"|????-??-??)
            _use_snapshot "${ROS_REPO}"
            ;;
        "false")
                export ROS_REPOSITORY_PATH=$current_repository_path
            ;;
        *)
            ici_error "ROS repo '$ROS_REPO' is not supported"
            ;;
        esac
    fi
}

function ici_configure_ros() {
    if [ -n "${ROS_DISTRO}" ]; then
        _set_ros_defaults
    fi
}

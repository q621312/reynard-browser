TARGET := iphone:clang:latest:14.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := Reynard
include $(THEOS)/makefiles/common.mk

TWEAK_NAME := ReynardKeepAwake
ReynardKeepAwake_FILES := src/ReynardKeepAwake.m
ReynardKeepAwake_FRAMEWORKS := UIKit
ReynardKeepAwake_CFLAGS := -fobjc-arc
ReynardKeepAwake_LDFLAGS := -Wl,-undefined,dynamic_lookup
include $(THEOS_MAKE_PATH)/tweak.mk

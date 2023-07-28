find_library(OPENH264_LIBRARIES NAMES openh264 HINTS lib)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(OPENH264 DEFAULT_MSG OPENH264_LIBRARIES)

mark_as_advanced(OPENH264_LIBRARIES)

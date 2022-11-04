#pragma once

#define WAPI_XLIB 0
#define WAPI_WIN32 1

#define RAPI_VULKAN 0

#if defined(_WIN32)
#define WINDOWING_API WAPI_WIN32
#elif defined(__linux__)
#define WINDOWING_API WAPI_XLIB
#else
#error Could not select windowing API based on target
#endif

#if 1
#define RENDERING_API RAPI_VULKAN
#else
#error Could not select rendering API based on target
#endif

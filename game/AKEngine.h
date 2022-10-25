#pragma once

#include "AKDefines.h"
#include "AKUtils.h"

#if defined(AK_USE_WIN32)
#include "AKWin32Window.h"
#elif defined(AK_USE_XLIB)
#include "AKXlibWindow.h"
#else
#error No windowing system selected
#endif
#include "AKWindow.h"

#if defined(AK_USE_VULKAN)
#include "AKVkRenderer.h"
#else
#error No rendering system selected
#endif
#include "AKRenderer.h"

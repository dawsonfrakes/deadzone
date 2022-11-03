#include "core.h"

GameWindow window_init(Input *const input, const char *const title)
{
    GameWindow result = {0};
    result.input = input;
    assert(result.inst = GetModuleHandleA(null));
    assert(RegisterClassA(&(const WNDCLASSA) {
        .style = CS_OWNDC|CS_HREDRAW|CS_VREDRAW,
        .lpfnWndProc = DefWindowProcA,
        .hInstance = result.inst,
        .lpszClassName = "game_window_class",
    }));
    assert(result.hwnd = CreateWindowExA(
        0,
        "game_window_class",
        (title ? title : "Window Title"),
        WS_OVERLAPPEDWINDOW|WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT,
        CW_USEDEFAULT, CW_USEDEFAULT,
        null,
        null,
        result.inst,
        null
    ));
    return result;
}

b32 window_update(GameWindow *const window)
{
    MSG msg;
    while (PeekMessageA(&msg, 0, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT) {
            return false;
        }
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }
    return true;
}

void window_deinit(const GameWindow *const window)
{
}

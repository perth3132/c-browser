#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#define CINTERFACE

#include <windows.h>
#include <objbase.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "vendor/webview2/build/native/include/WebView2.h"

#define ID_ADDRESS 1001
#define ID_GO 1002
#define ID_BACK 1003
#define ID_FORWARD 1004
#define ID_REFRESH 1005
#define MAX_URL 2048

static HWND address_bar;
static HWND main_window;
static ICoreWebView2Environment *webview_environment;
static ICoreWebView2Controller *webview_controller;
static ICoreWebView2 *webview;
static int shutting_down;
static int webview_starting;
static int using_system_runtime;
static int use_fixed_runtime;

static const wchar_t initial_url[] = L"https://www.ebay.com.au";
static wchar_t fixed_runtime_path[MAX_PATH];
static wchar_t user_data_path[MAX_PATH];

typedef struct {
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler iface;
} EnvironmentHandler;

typedef struct {
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler iface;
} ControllerHandler;

static EnvironmentHandler environment_handler;
static ControllerHandler controller_handler;

static HRESULT STDMETHODCALLTYPE environment_handler_query_interface(void *self, REFIID riid, void **object) {
    if (!object) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) ||
        IsEqualIID(riid, &IID_ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler)) {
        *object = self;
        return S_OK;
    }
    *object = NULL;
    return E_NOINTERFACE;
}

static HRESULT STDMETHODCALLTYPE controller_handler_query_interface(void *self, REFIID riid, void **object) {
    if (!object) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) ||
        IsEqualIID(riid, &IID_ICoreWebView2CreateCoreWebView2ControllerCompletedHandler)) {
        *object = self;
        return S_OK;
    }
    *object = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE handler_add_ref(void *self) {
    (void)self;
    return 1;
}

static ULONG STDMETHODCALLTYPE handler_release(void *self) {
    (void)self;
    return 1;
}

static void show_webview_error(HRESULT error) {
    char message[160];
    snprintf(message, sizeof(message), "WebView2 could not start (error 0x%08lx).\nInstall Microsoft Edge WebView2 Runtime.", (unsigned long)error);
    MessageBoxA(main_window, message, "C Browser", MB_ICONERROR);
}

static void resize_webview(void) {
    RECT bounds;
    if (!webview_controller) return;
    GetClientRect(main_window, &bounds);
    bounds.top = 48;
    webview_controller->lpVtbl->put_Bounds(webview_controller, bounds);
}

static void dispose_webview(void) {
    shutting_down = 1;
    webview_starting = 0;
    if (webview_controller) {
        webview_controller->lpVtbl->Close(webview_controller);
        webview_controller->lpVtbl->Release(webview_controller);
        webview_controller = NULL;
    }
    if (webview) {
        webview->lpVtbl->Release(webview);
        webview = NULL;
    }
    if (webview_environment) {
        webview_environment->lpVtbl->Release(webview_environment);
        webview_environment = NULL;
    }
}

static void navigate_to_address(void) {
    char url[MAX_URL];
    wchar_t wide_url[MAX_URL];

    GetWindowTextA(address_bar, url, sizeof(url));
    if (strncmp(url, "http://", 7) != 0 && strncmp(url, "https://", 8) != 0) {
        char normalized[MAX_URL];
        snprintf(normalized, sizeof(normalized), "https://%s", url);
        strncpy_s(url, sizeof(url), normalized, _TRUNCATE);
        SetWindowTextA(address_bar, url);
    }
    if (MultiByteToWideChar(CP_UTF8, 0, url, -1, wide_url, MAX_URL) > 0 && webview) {
        webview->lpVtbl->Navigate(webview, wide_url);
    }
}

static HRESULT STDMETHODCALLTYPE controller_handler_invoke(
    ICoreWebView2CreateCoreWebView2ControllerCompletedHandler *self,
    HRESULT error_code, ICoreWebView2Controller *controller) {
    RECT bounds;
    (void)self;
    if (shutting_down) return S_OK;
    if (FAILED(error_code) || !controller) {
        if (!using_system_runtime) {
            using_system_runtime = 1;
            if (controller) controller->lpVtbl->Release(controller);
            if (webview_environment) {
                webview_environment->lpVtbl->Release(webview_environment);
                webview_environment = NULL;
            }
            return CreateCoreWebView2EnvironmentWithOptions(NULL, user_data_path, NULL, &environment_handler.iface);
        }
        webview_starting = 0;
        show_webview_error(error_code);
        return error_code;
    }
    webview_starting = 0;
    webview_controller = controller;
    controller->lpVtbl->AddRef(controller);
    GetClientRect(main_window, &bounds);
    bounds.top = 48;
    controller->lpVtbl->put_Bounds(controller, bounds);
    controller->lpVtbl->put_IsVisible(controller, TRUE);
    controller->lpVtbl->get_CoreWebView2(controller, &webview);
    if (webview) webview->lpVtbl->Navigate(webview, initial_url);
    return S_OK;
}

static ICoreWebView2CreateCoreWebView2ControllerCompletedHandlerVtbl controller_handler_vtbl = {
    (void *)controller_handler_query_interface,
    (void *)handler_add_ref,
    (void *)handler_release,
    controller_handler_invoke
};

static HRESULT STDMETHODCALLTYPE environment_handler_invoke(
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler *self,
    HRESULT error_code, ICoreWebView2Environment *environment) {
    (void)self;
    if (shutting_down) return S_OK;
    if (FAILED(error_code) || !environment) {
        if (!using_system_runtime) {
            using_system_runtime = 1;
            return CreateCoreWebView2EnvironmentWithOptions(NULL, user_data_path, NULL, &environment_handler.iface);
        }
        webview_starting = 0;
        show_webview_error(error_code);
        return error_code;
    }
    webview_environment = environment;
    memset(&controller_handler, 0, sizeof(controller_handler));
    controller_handler.iface.lpVtbl = &controller_handler_vtbl;
    return environment->lpVtbl->CreateCoreWebView2Controller(environment, main_window, &controller_handler.iface);
}

static ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandlerVtbl environment_handler_vtbl = {
    (void *)environment_handler_query_interface,
    (void *)handler_add_ref,
    (void *)handler_release,
    environment_handler_invoke
};

static void start_webview(void) {
    HRESULT error;
    wchar_t local_app_data[MAX_PATH];
    DWORD local_app_data_length;
    wchar_t executable_path[MAX_PATH];
    wchar_t *last_separator;

    if (webview || webview_environment || webview_starting) return;
    shutting_down = 0;
    webview_starting = 1;
    use_fixed_runtime = GetEnvironmentVariableW(L"CBROWSER_USE_FIXED_RUNTIME", NULL, 0) > 1;
    using_system_runtime = !use_fixed_runtime;
    GetModuleFileNameW(NULL, executable_path, MAX_PATH);
    last_separator = wcsrchr(executable_path, L'\\');
    if (last_separator) *last_separator = L'\0';
    swprintf_s(fixed_runtime_path, MAX_PATH, L"%s\\WebView2FixedRuntime", executable_path);
    {
        if (use_fixed_runtime) {
            wchar_t runtime_executable[MAX_PATH];
            swprintf_s(runtime_executable, MAX_PATH, L"%s\\msedgewebview2.exe", fixed_runtime_path);
            if (GetFileAttributesW(runtime_executable) == INVALID_FILE_ATTRIBUTES) {
                webview_starting = 0;
                MessageBoxW(main_window,
                    L"The fixed WebView2 runtime is missing. Run install.ps1 first.",
                    L"C Browser", MB_ICONERROR);
                return;
            }
        }
    }
    local_app_data_length = GetEnvironmentVariableW(L"LOCALAPPDATA", local_app_data, MAX_PATH);
    if (local_app_data_length == 0 || local_app_data_length >= MAX_PATH) {
        show_webview_error(E_INVALIDARG);
        webview_starting = 0;
        return;
    }
    swprintf_s(user_data_path, MAX_PATH, L"%s\\CWebBrowser\\UserData", local_app_data);
    {
        wchar_t parent_path[MAX_PATH];
        swprintf_s(parent_path, MAX_PATH, L"%s\\CWebBrowser", local_app_data);
        CreateDirectoryW(parent_path, NULL);
    }
    CreateDirectoryW(user_data_path, NULL);
    memset(&environment_handler, 0, sizeof(environment_handler));
    environment_handler.iface.lpVtbl = &environment_handler_vtbl;
    error = CreateCoreWebView2EnvironmentWithOptions(
        use_fixed_runtime ? fixed_runtime_path : NULL,
        user_data_path, NULL, &environment_handler.iface);
    if (FAILED(error)) {
        using_system_runtime = 1;
        error = CreateCoreWebView2EnvironmentWithOptions(NULL, user_data_path, NULL, &environment_handler.iface);
        if (FAILED(error)) {
            webview_starting = 0;
            show_webview_error(error);
        }
    }
}

static LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    switch (message) {
        case WM_CREATE:
            main_window = window;
            address_bar = CreateWindowExA(WS_EX_CLIENTEDGE, "EDIT", "https://www.ebay.com.au",
                WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL, 170, 10, 520, 28,
                window, (HMENU)ID_ADDRESS, NULL, NULL);
            CreateWindowA("BUTTON", "Back", WS_CHILD | WS_VISIBLE, 10, 10, 70, 28,
                window, (HMENU)ID_BACK, NULL, NULL);
            CreateWindowA("BUTTON", "Forward", WS_CHILD | WS_VISIBLE, 85, 10, 80, 28,
                window, (HMENU)ID_FORWARD, NULL, NULL);
            CreateWindowA("BUTTON", "Go", WS_CHILD | WS_VISIBLE, 695, 10, 55, 28,
                window, (HMENU)ID_GO, NULL, NULL);
            CreateWindowA("BUTTON", "Refresh", WS_CHILD | WS_VISIBLE, 755, 10, 75, 28,
                window, (HMENU)ID_REFRESH, NULL, NULL);
            start_webview();
            return 0;
        case WM_COMMAND:
            if (LOWORD(wparam) == ID_GO || (LOWORD(wparam) == ID_ADDRESS && HIWORD(wparam) == EN_UPDATE && GetKeyState(VK_RETURN) < 0)) {
                navigate_to_address();
            } else if (LOWORD(wparam) == ID_BACK && webview) {
                webview->lpVtbl->GoBack(webview);
            } else if (LOWORD(wparam) == ID_FORWARD && webview) {
                webview->lpVtbl->GoForward(webview);
            } else if (LOWORD(wparam) == ID_REFRESH && webview) {
                webview->lpVtbl->Reload(webview);
            }
            return 0;
        case WM_SIZE:
            MoveWindow(address_bar, 170, 10, LOWORD(lparam) - 320, 28, TRUE);
            MoveWindow(GetDlgItem(window, ID_GO), LOWORD(lparam) - 130, 10, 55, 28, TRUE);
            MoveWindow(GetDlgItem(window, ID_REFRESH), LOWORD(lparam) - 75, 10, 75, 28, TRUE);
            if (wparam == SIZE_MINIMIZED) {
                dispose_webview();
            } else if (webview_controller) {
                webview_controller->lpVtbl->put_IsVisible(webview_controller, TRUE);
                resize_webview();
            } else if (!webview_starting) {
                start_webview();
            }
            return 0;
        case WM_SHOWWINDOW:
            if (!wparam) {
                dispose_webview();
            }
            return 0;
        case WM_DESTROY:
            dispose_webview();
            CoUninitialize();
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcA(window, message, wparam, lparam);
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command_line, int show_command) {
    WNDCLASSA window_class = {0};
    HWND window;
    MSG message;

    (void)previous;
    (void)command_line;
    if (FAILED(CoInitializeEx(NULL, COINIT_APARTMENTTHREADED))) return 1;
    window_class.lpfnWndProc = window_proc;
    window_class.hInstance = instance;
    window_class.lpszClassName = "CWebViewBrowserWindow";
    window_class.hCursor = LoadCursor(NULL, IDC_ARROW);
    window_class.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClassA(&window_class);
    window = CreateWindowA(window_class.lpszClassName, "C Browser",
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 1100, 760,
        NULL, NULL, instance, NULL);
    if (!window) {
        CoUninitialize();
        return 1;
    }
    ShowWindow(window, show_command);
    UpdateWindow(window);
    while (GetMessageA(&message, NULL, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageA(&message);
    }
    return (int)message.wParam;
}

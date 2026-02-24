#define WIN32_LEAN_AND_MEAN

// clang-format off
#include <windows.h>
#include <mmsystem.h>
// clang-format on

#include <stdatomic.h>
#include <stddef.h> // for unreachable()
#include <stdio.h>

// Link with winmm.lib
#pragma comment(lib, "winmm.lib")

// ============================================================
// GLOBALS
// ============================================================
static atomic_bool is_shaking = false;

// ============================================================
// CONSTANTS & MACROS
// ============================================================
static const char *const PIPE_NAME = "\\\\.\\pipe\\nvim_clack";
static constexpr DWORD PIPE_BUFFER_SIZE = 1024;
static constexpr DWORD PIPE_MAX_INST = PIPE_UNLIMITED_INSTANCES;
static constexpr DWORD READ_BUFFER_SIZE = 1;
static constexpr DWORD RETRY_DELAY_MS = 1000;
static constexpr DWORD IDLE_YIELD_MS = 10;

static constexpr int SHAKE_ITERATIONS = 6;
static constexpr int SHAKE_AMPLITUDE_PX = 15;
static constexpr DWORD SHAKE_DELAY_MS = 20;

// ============================================================
// WINDOW SEARCH TYPES
// ============================================================
typedef struct {
  DWORD target_pid;
  HWND best_hwnd;
  long max_area;
} WindowSearchParams;

static constexpr int MIN_WINDOW_DIMENSION = 100;

// ============================================================
// WINDOW ENUMERATION CALLBACK
// ============================================================
static BOOL CALLBACK FindTerminalWindowProc(HWND hwnd, LPARAM l_param) {
  WindowSearchParams *params = (WindowSearchParams *)(void *)l_param;

  DWORD window_pid = 0;
  GetWindowThreadProcessId(hwnd, &window_pid);

  // Filter by PID and Visibility
  if (window_pid == params->target_pid && IsWindowVisible(hwnd) != FALSE) {
    RECT rect;
    if (GetWindowRect(hwnd, &rect) != FALSE) {
      long width = rect.right - rect.left;
      long height = rect.bottom - rect.top;
      long area = width * height;

      // The actual terminal frame is always the largest visible window
      // belonging to the process. We ignore tiny utility windows.
      if (area > params->max_area && width > MIN_WINDOW_DIMENSION) {
        params->max_area = area;
        params->best_hwnd = hwnd;
      }
    }
  }
  return TRUE; // Continue searching all windows
}

// ============================================================
// WINDOW MANIPULATION (The Earthquake)
// ============================================================
static void ShakeWindowsTerminal(void) {
  HWND active_hwnd = GetForegroundWindow();
  if (active_hwnd == nullptr)
    return;

  DWORD current_pid = 0;
  GetWindowThreadProcessId(active_hwnd, &current_pid);

  // Search for the largest window owned by the foreground process
  WindowSearchParams params = {
      .target_pid = current_pid, .best_hwnd = nullptr, .max_area = 0};
  EnumWindows(FindTerminalWindowProc, (LPARAM)(void *)&params);

  if (params.best_hwnd == nullptr)
    return;

  RECT rect;
  if (GetWindowRect(params.best_hwnd, &rect) != FALSE &&
      IsZoomed(params.best_hwnd) == FALSE) {
    for (int i = 0; i < SHAKE_ITERATIONS; i++) {
      const int offset_x =
          (i % 2 == 0) ? SHAKE_AMPLITUDE_PX : -SHAKE_AMPLITUDE_PX;

      // SWP_NOSIZE | SWP_NOZORDER ensures we only change the X/Y position
      SetWindowPos(params.best_hwnd, nullptr, rect.left + offset_x, rect.top, 0,
                   0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
      Sleep(SHAKE_DELAY_MS);
    }

    // Final snap back to the exact original coordinates
    SetWindowPos(params.best_hwnd, nullptr, rect.left, rect.top, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  }
}

static DWORD WINAPI ShakeThread([[maybe_unused]] LPVOID parameter) {
  ShakeWindowsTerminal();
  atomic_store(&is_shaking, false);
  return 0;
}

static void TriggerShakeBackground(void) {
  // Atomic check-and-set to prevent overlapping shakes
  if (!atomic_exchange(&is_shaking, true)) {
    HANDLE thread_handle =
        CreateThread(nullptr, 0, ShakeThread, nullptr, 0, nullptr);

    if (thread_handle != nullptr) {
      CloseHandle(thread_handle); // Detach thread
    } else {
      atomic_store(&is_shaking, false); // Fallback unlock
    }
  }
}

// ============================================================
// LOGIC HELPERS (Complexity Reduction)
// ============================================================

// 1. Encapsulate Pipe Creation Retry Logic
[[nodiscard]]
static HANDLE CreatePipeInstance(void) {
  HANDLE hPipe = INVALID_HANDLE_VALUE;
  while (hPipe == INVALID_HANDLE_VALUE) {
    hPipe = CreateNamedPipeA(PIPE_NAME, PIPE_ACCESS_INBOUND,
                             PIPE_TYPE_BYTE | PIPE_WAIT, PIPE_MAX_INST,
                             PIPE_BUFFER_SIZE, PIPE_BUFFER_SIZE, 0, nullptr);

    if (hPipe == INVALID_HANDLE_VALUE) {
      printf(
          "Pipe busy or creation failed (Error %lu). Retrying in %lu ms...\n",
          GetLastError(), RETRY_DELAY_MS);
      Sleep(RETRY_DELAY_MS);
    }
  }
  return hPipe;
}

// 2. Encapsulate Sound Selection & Side Effects
[[nodiscard]]
static const char *DetermineSoundAndAction(char code) {
  switch (code) {
  case 'e':
    return SOUND_ENTER;
  case 's':
    return SOUND_SPACE;
  case 'x':
    TriggerShakeBackground();
    return SOUND_ENTER;
  default:
    return SOUND_CLICK;
  }
}

// 3. Encapsulate the Read Loop
static void HandleClientSession(HANDLE hPipe) {
  char buffer = 0;
  DWORD bytesRead = 0;

  while (ReadFile(hPipe, &buffer, READ_BUFFER_SIZE, &bytesRead, nullptr)) {
    if (bytesRead > 0) {
      const char *soundPath = DetermineSoundAndAction(buffer);
      PlaySoundA(soundPath, nullptr, SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
      buffer = 0; // Clear buffer for next read
    }
  }
}

// ============================================================
// MAIN
// ============================================================
int main() {
  printf("Starting Neovim Sound Daemon (C23)...\n");
  printf("Listening on %s\n", PIPE_NAME);

  HANDLE hPipe = CreatePipeInstance();

  while (true) {
    // Wait for a client connection
    BOOL connected = ConnectNamedPipe(hPipe, nullptr)
                         ? TRUE
                         : (GetLastError() == ERROR_PIPE_CONNECTED);

    if (connected) {
      HandleClientSession(hPipe);
    } else {
      // Yield CPU if connection failed but pipe is valid
      Sleep(IDLE_YIELD_MS);
    }

    // Reset pipe for next client
    DisconnectNamedPipe(hPipe);
  }

  // Compiler knows execution never passes here
  unreachable();
}

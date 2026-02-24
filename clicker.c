#define WIN32_LEAN_AND_MEAN

// clang-format off
#include <windows.h>
#include <mmsystem.h>
// clang-format on

#include <stdio.h>

// Link with winmm.lib
#pragma comment(lib, "winmm.lib")

// ============================================================
// TYPE-SAFE CONSTANTS (C23)
// ============================================================
static const char *const PIPE_NAME = "\\\\.\\pipe\\nvim_clack";

// Clang-Tidy: Added static to internal constexpr definitions
static constexpr DWORD PIPE_BUFFER_SIZE = 1024;
static constexpr DWORD PIPE_MAX_INST = PIPE_UNLIMITED_INSTANCES;
static constexpr DWORD READ_BUFFER_SIZE = 1;
static constexpr DWORD RETRY_DELAY_MS = 1000;

// ============================================================
// MAIN
// ============================================================
int main() {
  printf("Starting Neovim Sound Daemon (C23)...\n");
  printf("Listening on %s\n", PIPE_NAME);

  HANDLE hPipe = INVALID_HANDLE_VALUE;

  // Initial Creation Loop: Uses RETRY_DELAY_MS to wait if pipe is busy
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

  // Main Daemon Loop
  while (true) {
    // Wait for Neovim to connect
    if (ConnectNamedPipe(hPipe, nullptr) ||
        GetLastError() == ERROR_PIPE_CONNECTED) {
      char buffer = 0;
      DWORD bytesRead = 0;

      // Read loop: Process all bytes until Neovim disconnects
      while (ReadFile(hPipe, &buffer, READ_BUFFER_SIZE, &bytesRead, nullptr) !=
             FALSE) {
        if (bytesRead == 0) {
          continue;
        }

        const char *soundPath;
        switch (buffer) {
        case 'e':
          soundPath = "C:\\Users\\PC\\AppData\\Local\\nvim\\sounds\\enter.wav";
          break;
        case 's':
          soundPath = "C:\\Users\\PC\\AppData\\Local\\nvim\\sounds\\space.wav";
          break;
        default:
          soundPath = "C:\\Users\\PC\\AppData\\Local\\nvim\\sounds\\click.wav";
          break;
        }

        // Asynchronous playback: no delay between typing and clacking
        PlaySoundA(soundPath, nullptr,
                   SND_FILENAME | SND_ASYNC | SND_NODEFAULT);
      }
    }

    // Prepare the pipe for the next potential connection/instance
    DisconnectNamedPipe(hPipe);
  }

  // Technically unreachable, but good practice
  CloseHandle(hPipe);
  return 0;
}

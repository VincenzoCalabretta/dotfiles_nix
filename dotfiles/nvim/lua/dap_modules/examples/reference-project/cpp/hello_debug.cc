// Minimal target for exercising dap_modules' local gdbserver flow:
//   bazel run --config=gdbnf //cpp:hello_debug
// then <leader>bC in Neovim (see ../README.md).
//
// Loops forever, slowly, printing each step -- deliberately not CPU-bound so
// there's plenty of time to attach and set a breakpoint before it matters.

#include <chrono>
#include <cstdio>
#include <thread>

namespace {

int compute_step(int counter) {
  int squared = counter * counter;  // <-- set a breakpoint here (<M-b>)
  return squared;
}

}  // namespace

int main() {
  for (int counter = 0;; ++counter) {
    int result = compute_step(counter);
    std::printf("counter=%d result=%d\n", counter, result);
    std::fflush(stdout);
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
  }
}

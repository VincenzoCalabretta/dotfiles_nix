"""Minimal target for exercising dap_modules' debugpy flow.

Run with: bazel run --config=debugpy //python:hello_debug
then <leader>gp in Neovim (see ../README.md).

debugpy (via the `.bazelrc` `debugpy` config's --wait-for-client) pauses
execution until Neovim attaches, so there's no race to catch it running.
"""

import time


def compute_step(counter: int) -> int:
    squared = counter * counter  # <-- set a breakpoint here (<M-b>)
    return squared


def main() -> None:
    counter = 0
    while True:
        result = compute_step(counter)
        print(f"counter={counter} result={result}", flush=True)
        counter += 1
        time.sleep(0.5)


if __name__ == "__main__":
    main()

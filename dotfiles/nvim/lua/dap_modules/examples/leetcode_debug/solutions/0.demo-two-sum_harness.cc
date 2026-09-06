// Hand-written stand-in for what leetcode_modules/harness.lua (Phase 2)
// will generate from q.meta_data + the testcase popup buffer:
//   bazel run --config=gdbnf //solutions:demo_two_sum_debug
// then <leader>bC in Neovim (see dap_modules/README.md), breakpoint in
// 0.demo-two-sum.cpp.
#include <cstdio>
#include "0.demo-two-sum.cpp"

namespace {

void print_vec(const std::vector<int>& v) {
  std::printf("[");
  for (size_t i = 0; i < v.size(); ++i) {
    std::printf("%s%d", i ? "," : "", v[i]);
  }
  std::printf("]\n");
}

}  // namespace

int main() {
  std::vector<int> nums = {2, 7, 11, 15};
  int target = 9;

  auto result = Solution().twoSum(nums, target);
  std::printf("expected=[0,1] got=");
  print_vec(result);
}

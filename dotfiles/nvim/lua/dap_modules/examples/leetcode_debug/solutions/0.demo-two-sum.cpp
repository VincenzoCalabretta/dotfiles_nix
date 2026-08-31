// Demo solution proving the $LEETCODE_STORAGE_HOME -> Bazel -> dap_modules
// wiring, ahead of leetcode_modules/harness.lua (Phase 2) generating this
// pairing automatically from whatever real problem is open. Frontend id 0
// deliberately doesn't collide with a real LeetCode problem (they start at
// 1), so this file never gets mistaken for actual progress.
//
// Deliberately buggy: returns indices in the wrong order for one branch, to
// give the debugger something to actually catch (see 0.demo-two-sum_harness.cc).
#include <vector>

class Solution {
 public:
  std::vector<int> twoSum(std::vector<int>& nums, int target) {
    for (int i = 0; i < static_cast<int>(nums.size()); ++i) {
      for (int j = i + 1; j < static_cast<int>(nums.size()); ++j) {
        if (nums[i] + nums[j] == target) {
          int first = j;   // <-- set a breakpoint here (<M-b>): should be i
          int second = i;  //     should be j
          return {first, second};
        }
      }
    }
    return {};
  }
};

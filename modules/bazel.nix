{ config, pkgs, ... }:

# Bazel build tool, with a disk cache shared across all projects so build
# outputs survive across checkouts/clones instead of being rebuilt from
# scratch each time.
{
  home.packages = [ pkgs.bazel_9 ];

  # $HOME/.bazelrc is loaded automatically for every Bazel invocation (before
  # any project's own .bazelrc, unless run with --nohome_rc), so this applies
  # by default without needing per-project configuration.
  home.file.".bazelrc".text = ''
    # common (not just build) so bazel fetch/query/sync also share these caches.
    common --disk_cache=${config.home.homeDirectory}/.cache/bazel/disk-cache
    common --experimental_disk_cache_gc_max_size=100G
    common --repository_cache=${config.home.homeDirectory}/.cache/bazel/repo-cache

    build --verbose_failures
    build --keep_going

    test --test_output=errors

    common --color=yes
  '';
}

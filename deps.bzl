load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository", "new_git_repository")

def _maybe(repo_rule, name, **kwargs):
    """Executes the given repository rule if it hasn't been executed already.
    Args:
      repo_rule: The repository rule to be executed (e.g., `http_archive`.)
      name: The name of the repository to be defined by the rule.
      **kwargs: Additional arguments passed directly to the repository rule.
    """
    if not native.existing_rule(name):
        repo_rule(name = name, **kwargs)

def s4nnc_deps():
    """Loads common dependencies needed to compile the s4nnc library."""

    _maybe(
        git_repository,
        name = "ccv",
        remote = "https://github.com/liuliu/ccv.git",
        commit = "12621a156f6c64d0da4476d962afd3eb1f4f3f2d",
        shallow_since = "1618438344 -0400",
    )

    _maybe(
        new_git_repository,
        name = "PythonKit",
        remote = "https://github.com/liuliu/PythonKit.git",
        commit = "e7d0bbc18c9b7937a04dd876e21f04c19bf902d8",
        shallow_since = "1630607311 -0400",
        build_file = "@s4nnc//:external/PythonKit.BUILD",
    )

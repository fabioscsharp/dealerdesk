# Releasing and CI for DealerDesk

This is a new file (spec 003). The older `RELEASE.txt` is kept as it is; this file explains
the automated parts and the steps a person still has to do. The release steps are added
below the CI part.

## What CI does

Every pull request, and every push to `master`, runs `.github/workflows/ci.yml` on a clean
Ubuntu machine, once with gcc and once with clang. Each run executes one script:

```sh
sh scripts/check.sh
```

It runs, in this order, and reports every step that failed:

1. `make clean && make test`: build, pricing unit tests, end-to-end tests.
2. `make test-mutation`: changes the VAT constant in a copy and checks that the suite then
   fails, so the tests really would catch a pricing error.
3. `make test-compat`: builds the old `a2ba708` binary from git history and checks that it
   still reads the data written now (the rollback promise, see E-05 in `assumptions.md`).
4. A clean-tree check: `git status --porcelain` must be the same after the checks as before.

`check: ALL PASSED` means the change is safe to merge. The CI job checks out the full git
history because step 3 needs it. The build uses `-Wall` and not `-Werror` (the legacy code).
When `gcc` passes after a push to `master`, the built `dealerdesk` binary is kept as a
workflow artifact.

### Run the same checks on your machine

On Linux, macOS or WSL with `make`, gcc or clang and git, from the repository root:

```sh
sh scripts/check.sh
CC=clang sh scripts/check.sh
```

Restore the sample data after any manual run with `git checkout -- data`.

## Required check on `master` (manual, once)

CI only protects `master` if GitHub is told that a failing run blocks the merge. This is a
repository setting. It is not a file, so someone with admin rights has to apply it:

1. On GitHub open the `fabioscsharp/dealerdesk` repository, then Settings, then Branches.
2. Add a branch protection rule (or edit the existing one) for `master`.
3. Tick "Require status checks to pass before merging".
4. Search for and add the check named `build-and-test`. It is the aggregate job in
   `ci.yml`: it passes only when both compiler legs (`checks (gcc)` and `checks (clang)`)
   passed, so it is the only name to require. It appears in the list after CI has run once.
5. Save.

Confirm it works with a throwaway pull request: change the VAT constant in `calc.c`
(`0.20` to `0.21`), open a draft pull request, and check that `build-and-test` goes red and
the merge button is blocked. Close that pull request without merging.

Record who applied the setting and when (spec 003, task T013).

## Notes

- The workflows use `actions/checkout@v4` and `actions/upload-artifact@v4`, pinned to a
  major version. Pinning them to full commit SHAs is stronger and is a possible later step.
- Workflows contain no logic of their own: they call the scripts in `scripts/`, so anything
  CI does can be run and debugged locally.

## Compatibility

| OS              | Supported | Notes          |
| --------------- | --------- | -------------- |
| Debian / Ubuntu | ✓ tested  | Primary target |
| Alpine Linux    | ✓ tested  | Tested in CI   |

**Architectures:** x86_64, aarch64

**Alpine / musl note:** upstream only ships glibc-linked binaries, so on musl the feature installs the npm package under a private Node 24 runtime (`/usr/local/lib/gitlab-ci-local`, checksum-verified from unofficial-builds.nodejs.org) and puts a wrapper at `/usr/local/bin/gitlab-ci-local`. No global `node` is added to `PATH`.

**Runtime note:** `gitlab-ci-local` requires Docker to be available at runtime to execute pipeline jobs.

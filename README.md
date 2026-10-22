# [gopls](https://github.com/golang/tools/blob/master/gopls/README.md) in a snap #

-------------------------------------------------------------------------------

[![gopls](https://snapcraft.io/gopls/badge.svg)](https://snapcraft.io/gopls)

## Installation ##

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-black.svg)](https://snapcraft.io/gopls)

``` shell
sudo snap install gopls --classic
```

([Don't have snapd installed?](https://snapcraft.io/docs/core/install))

## Testing ##

System-level [spread](https://github.com/canonical/spread) tests in `tests/`
install the snap on Ubuntu 20.04, 22.04, 24.04 and 26.04 VMs (via
[image-garden](https://gitlab.com/zygoon/image-garden), so `/dev/kvm` access
is needed) and check that gopls works both from its CLI and as an LSP server
for a real editor client (headless Neovim).

``` shell
sudo snap install image-garden

# test a locally built snap (the newest gopls_*.snap in the project dir)
snapcraft pack
spread garden:...:local

# or a store channel, e.g. latest/edge on a single release
spread garden:ubuntu-cloud-24.04:tests/...:latest_edge
```

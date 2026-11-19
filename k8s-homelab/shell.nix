{
  pkgs ? import <nixpkgs> {
    config.allowUnfree = true;
  },
}:

pkgs.mkShell {
  name = "k8s-homelab-env";
  packages = with pkgs; [
    age
    ansible
    ansible-lint
    cdrkit
    jq
    pulumi
    sops
    vagrant
    yamllint
  ];

  shellHook = ''
    export VAGRANT_DEFAULT_PROVIDER=libvirt
    export VAGRANT_HOME="/data/downloads/vagrant-boxes"
    export ERRANT_CACHE_DIR="/data/downloads/errant-images"
    export LIBVIRT_DEFAULT_URI="qemu:///system"
    if [ -d "/home/xeno/git/gitea/errant/dist" ]; then
      export PATH="/home/xeno/git/gitea/errant/dist:$PATH"
    fi
    echo "=== k8s-homelab Libvirt Environment Loaded ==="
    echo "Vagrant: $(vagrant --version)"
    if command -v errant >/dev/null 2>&1; then
      echo "Errant: $(errant --version 2>/dev/null || echo 'available')"
    fi
    echo "Default provider: $VAGRANT_DEFAULT_PROVIDER"
    echo "Vagrant home: $VAGRANT_HOME"
    echo "Errant cache dir: $ERRANT_CACHE_DIR"
    echo "Libvirt default URI: $LIBVIRT_DEFAULT_URI"
  '';
}

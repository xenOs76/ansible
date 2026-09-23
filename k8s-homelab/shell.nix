{
  pkgs ? import <nixpkgs> {
    config.allowUnfree = true;
  },
}:

pkgs.mkShell {
  name = "k8s-homelab-env";
  packages = with pkgs; [
    ansible
    ansible-lint
    yamllint
    jq
    vagrant
  ];

  shellHook = ''
    export VAGRANT_DEFAULT_PROVIDER=libvirt
    export VAGRANT_HOME="/data/downloads/vagrant-boxes"
    echo "=== Vagrant Libvirt Environment Loaded ==="
    echo "Vagrant: $(vagrant --version)"
    echo "Default provider: $VAGRANT_DEFAULT_PROVIDER"
    echo "Vagrant home: $VAGRANT_HOME"
  '';
}

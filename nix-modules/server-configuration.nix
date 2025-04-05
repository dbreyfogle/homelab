{
  modulesPath,
  pkgs,
  inputs,
  terraform,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ./base-configuration.nix
  ];

  boot.loader.grub.enable = true;

  environment.systemPackages = with pkgs; [
    vim
  ];

  networking.hostName = "k3s-server-" + toString terraform.serverNum;

  networking.firewall.allowedTCPPorts = [
    80
    443
    2379 # etcd clients
    2380 # etcd peers
    6443 # api server
    9100 # prometheus node exporter
    10250 # kubelet metrics
  ];
  networking.firewall.allowedUDPPorts = [
    8472 # flannel
  ];

  services.k3s = {
    enable = true;
    role = "server";
    token = terraform.k3sToken;
    clusterInit = terraform.serverNum == 0;
    serverAddr = if terraform.serverNum != 0 then terraform.serverAddr else "";
  };
}

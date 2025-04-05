{ ... }:

{
  system.stateVersion = "24.11";
  nix.settings.experimental-features = "nix-command flakes";

  services.openssh.enable = true;
  services.qemuGuest.enable = true;

  users.users."root".openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILuPqZF8NYUWxdkxTHPtS2jUZvJ/3IyjRDp0X3vDVejr danny@nixos"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMf6cUfwAbS3md4Y1kA1A3wvjSu8M49vXsEDQ2IdurM4 danny@Dannys-MacBook-Pro.local"
  ];
}

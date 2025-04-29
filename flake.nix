{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      flake-utils,
      nixpkgs,
      nixpkgs-terraform,
      nixos-generators,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nixpkgs-terraform.overlays.default ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            hcp
            jq
            kubectl
            kubernetes-helm
            minikube
            nixVersions.nix_2_24 # nixos-anywhere terraform special_args are broken for nix > 2.24
            terraform-versions."1.11"
          ];
        };
      }
    )
    // (
      let
        system = "x86_64-linux";
      in
      {
        packages.${system}.default = nixos-generators.nixosGenerate {
          inherit system;
          modules = [ ./nix-modules/base-configuration.nix ];
          format = "qcow";
        };

        nixosConfigurations."k3s-server" = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ ./nix-modules/server-configuration.nix ];
        };
      }
    );
}

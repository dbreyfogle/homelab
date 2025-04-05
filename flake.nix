{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      flake-utils,
      nixpkgs,
      nixpkgs-unstable,
      nixos-generators,
      ...
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (
      system:
      let
        pkgs = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
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
            terraform
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

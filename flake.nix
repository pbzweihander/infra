{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-terraform.url = "github:stackbuilders/nixpkgs-terraform";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      nixpkgs-terraform,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        version = "1.13";
        overlays = [ nixpkgs-terraform.overlays.default ];
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
        terraform = pkgs.terraform-versions.${version};
      in
      {
        nixConfig = {
          extra-substituters = "https://nixpkgs-terraform.cachix.org";
          extra-trusted-public-keys = "nixpkgs-terraform.cachix.org-1:8Sit092rIdAVENA3ZVeH9hzSiqI/jng6JiCrQ1Dmusw=";
        };
        formatter = pkgs.nixfmt-rfc-style;
        devShells.default = pkgs.mkShell { nativeBuildInputs = [ terraform ]; };
      }
    );
}

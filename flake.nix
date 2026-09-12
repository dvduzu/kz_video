{
  description = "KzVideo - Flutter Android dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          flutter
          jdk21
          gradle
          android-tools
          pulseaudio
          libpng
          libbsd
          xorg.libXi
          xorg.libX11
          xorg.libXcomposite
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXrandr
          libxrender
          libxcb
          libglvnd
          mesa
          mpv
        ];

        shellHook = ''
          export ANDROID_HOME="$PWD/.tooling/sdk"
          export ANDROID_SDK_ROOT="$ANDROID_HOME"
          export ANDROID_USER_HOME="$PWD/.tooling/.android"
          export ANDROID_AVD_HOME="$PWD/.tooling/.android/avd"
          export GRADLE_USER_HOME="$PWD/.tooling/gradle"
          export PUB_CACHE="$PWD/.tooling/pub-cache"
          export XDG_CACHE_HOME="$PWD/.tooling/xdg-cache"
          export XDG_DATA_HOME="$PWD/.tooling/xdg-data"
          export XDG_CONFIG_HOME="$PWD/.tooling/xdg-config"
          export JAVA_HOME="${pkgs.jdk21}"
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.pulseaudio pkgs.libpng pkgs.libbsd pkgs.xorg.libXi pkgs.xorg.libX11 pkgs.xorg.libXcomposite pkgs.xorg.libXdamage pkgs.xorg.libXext pkgs.xorg.libXfixes pkgs.xorg.libXrandr pkgs.libxrender pkgs.libxcb pkgs.libglvnd pkgs.mesa ]}:$LD_LIBRARY_PATH"
        '';
      };
    };
}

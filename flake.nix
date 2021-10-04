{
  #description = "DaySquare rust dev environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
    rust-overlay.url = "github:oxalica/rust-overlay";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, utils, naersk, rust-overlay, sops-nix, ... }:
    let
      db_user = "daysquare";
      db_password = "daysquare";
      db_port = 5432;
      db_name = "daysquare";
      container_name = "dev-db";
      system = "x86_64-linux";
      naersk-lib = naersk.lib."${system}";
      overlays = [ (import rust-overlay) (sops-nix.overlay) ];
      pkgs = import nixpkgs {
        inherit system overlays;
      };

      sqlsConfigFile = ''
        lowercaseKeywords: false
        connections:
          - alias: dsn_daysquare
            driver: postgresql
            proto: tcp
            user: ${db_user}
            passwd: ${db_password}
            dbName: ${db_name}
            host: ${container_name}
            port: ${builtins.toString db_port}
      '';

    in
    rec {
      devShell."${system}" = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [
          # build inputs
          pkg-config
          openssl

          # encrypted config
          sops

          # rust
          (rust-bin.stable.latest.default.override {
            targets = [ "wasm32-unknown-unknown" "x86_64-unknown-linux-gnu" ];
          })
          cargo

          # cargo tools
          cargo-edit
          cargo-audit

          # database
          sqlx-cli
          postgresql

          # tracing format
          bunyan-rs

          # frontend build
          trunk
        ];

        shellHook = ''
          rm ./backend/config.yml
          echo ${"'" + sqlsConfigFile + "'"} > ./backend/config.yml
          sudo nixos-container destroy ${container_name}
          sudo nixos-container create ${container_name} --flake ".#db"
          sudo nixos-container start ${container_name}
          sqlx database create
          sqlx migrate --source ./backend/migrations run
        '';

        DATABASE_URL = "postgres://${db_user}:${db_password}@${container_name}:${builtins.toString db_port}/${db_name}";
        PGHOST = container_name;
        PGUSER = db_user;
        PGPORT = db_port;
        PGDATABASE = db_name;
      };
    } // {
      nixosConfigurations.db = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          ({ pkgs, ... }: {
            boot.isContainer = true;

            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

            networking.useDHCP = false;
            networking.firewall.allowedTCPPorts = [ db_port 80 ];

            services.postgresql = {
              enable = true;
              enableTCPIP = true;
              port = db_port;
              authentication = pkgs.lib.mkForce ''
                # Generate file, do not edit!
                # TYPE    DATABASE    USER    ADDRESS         METHOD
                local     all         all                     trust
                host      all         all     10.0.0.1/8      md5
                host      all         all     ::1/128         md5
              '';
              initialScript = pkgs.writeText "backend-initScript" ''
                CREATE USER ${db_user} WITH LOGIN ENCRYPTED PASSWORD ${"'" + db_password + "'"} CREATEDB;
                CREATE DATABASE ${db_name};
                GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
              '';
            };

            services.httpd = {
              enable = true;
              adminAddr = "test@example.org";
            };
          })
        ];
      };
    };
}

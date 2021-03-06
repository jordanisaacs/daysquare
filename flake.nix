{
  #description = "DaySquare rust dev environment";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    mongofix.url = "github:jordanisaacs/nixpkgs/mongodb-portfix";
    utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
    rust-overlay.url = "github:oxalica/rust-overlay";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, utils, naersk, rust-overlay, sops-nix, mongofix, ... }:
    let
      system = "x86_64-linux";
      naersk-lib = naersk.lib."${system}";
      overlays = [ (import rust-overlay) (sops-nix.overlay) ];
      pkgs = import nixpkgs {
        inherit system overlays;
      };

      server_db_user = "daysquare";
      server_db_password = "daysquare";
      server_db_port = 5432;
      server_db_name = "daysquare";
      server_db_container_name = "serverDB";

      server_port = 8000;

      redact_db_root_password = "daysquare";
      redact_db_local_addr = "10.250.0.3";
      redact_db_user = "daysquare";
      redact_db_password = "daysquare";
      redact_db_port = 4242;
      redact_db_name = "daysquare";
      redact_db_container_name = "redactDB";
      redact_db_conn_string = "mongodb://root:${redact_db_password}@${redact_db_local_addr}:${builtins.toString redact_db_port}/admin";

      redact_store_port = 8081;

      redact_tls_org = "pauwels";
      redact_store_tls_ca_path = "tls/server/cert/ca.pem";
      redact_client_tls_ca_folder = "certs";
      redact_client_tls_ca_path = redact_client_tls_ca_folder + "/storer-ca.pem";

      sqlsConfigFile = ''
        # Autogenerated: DO NOT EDIT
        # sqls configuration file

        lowercaseKeywords: false
        connections:
          - alias: dsn_daysquare
            driver: postgresql
            proto: tcp
            user: ${server_db_user}
            passwd: ${server_db_password}
            dbName: ${server_db_name}
            host: ${server_db_container_name}
            port: ${builtins.toString server_db_port}
      '';

      backendConfigFile = ''
        # Autogenerated: DO NOT EDIT
        # daysquare backend configuration file.

        database:
            host: ${server_db_container_name}
            port: ${builtins.toString server_db_port}
            username: ${server_db_user}
            password: ${server_db_password}
            database_name: ${server_db_name}
        server:
            host: 127.0.0.1
            application_port: ${toString server_port}
            secure: false
          
      '';

      redactStoreConfigFile = ''
        server:
          port: ${builtins.toString redact_store_port}
        tls:
          generate: true
          ca:
            certificate:
              o: ${redact_tls_org}
              ou: ca
              cn: storer
              expires_in: 365
              path: "${redact_store_tls_ca_path}"
            key:
              path: "tls/server/key/ca.pem"
          server:
            certificate:
              o: ${redact_tls_org}
              ou: tls
              cn: storer
              expires_in: 365
              path: "tls/server/cert/server.pem"
            key:
              path: "tls/server/key/server.pem"
        db:
          url: "${redact_db_conn_string}"
          name: "${redact_db_name}"
        google:
          storage:
            bucket:
              name: ""
      '';

      redactClientConfigFile = ''
        storage:
          url: https://localhost:${builtins.toString redact_store_port}
          tls:
            client:
              pkcs12:
                filepath: "keys/private/client-tls.p12.pem"
            server:
              ca:
                filepath: "${redact_client_tls_ca_path}"
        relayer:
          tls:
            client:
              pkcs12:
                filepath: "keys/private/client-tls.p12.pem"
            server:
              ca:
                filepath: ""
        certificates:
          signing:
            root:
              o: "${redact_tls_org}"
              ou: "signing"
              cn: "root"
              expires_in: 365
              filepath: "certs/root-signing.pem"
            tls:
              o: "${redact_tls_org}"
              ou: "tls"
              cn: "laptop"
              expires_in: 365
              filepath: "certs/client-tls.pem"
        keys:
          encryption:
            symmetric:
              default:
                path: ".keys.encryption.symmetric.default."
                builder:
                  t: "Key"
                  c:
                    t: "Symmetric"
                    c:
                      t: "SodiumOxide"
                      c: {}
                value:
                  t: "Unsealed"
                  c:
                    bytes:
                      t: "Fs"
                      c:
                        path:
                          path: "keys/private/.keys.encryption.symmetric.default."
                          stem: ".keys.encryption.symmetric.default."
          signing:
            root:
              path: ".keys.signing.root."
              builder:
                t: "Key"
                c:
                  t: "Asymmetric"
                  c:
                    t: "Secret"
                    c:
                      t: "SodiumOxideEd25519"
                      c: {}
              value:
                t: "Unsealed"
                c:
                  bytes:
                    t: "Fs"
                    c:
                      path:
                        path: "keys/private/.keys.signing.root."
                        stem: ".keys.signing.root."
            tls:
              path: ".keys.signing.tls."
              builder:
                t: "Key"
                c:
                  t: "Asymmetric"
                  c:
                    t: "Secret"
                    c:
                      t: "SodiumOxideEd25519"
                      c: {}
              value:
                t: "Unsealed"
                c:
                  bytes:
                    t: "Fs"
                    c:
                      path:
                        path: "keys/private/.keys.signing.tls."
                        stem: ".keys.signing.tls."
      '';


      containers =
        let
          serverDBInit = pkgs.writeText "serverdb-initScript" ''
            CREATE USER ${server_db_user} WITH LOGIN ENCRYPTED PASSWORD ${"'" + server_db_password + "'"} CREATEDB;
            CREATE DATABASE ${server_db_name};
            GRANT ALL PRIVILEGES ON DATABASE ${server_db_name} TO ${server_db_user};
          '';

          #db = db.getSiblingDB("admin");
          #db.grantRolesToUser('root', [{ role: 'root', db: 'admin' }]);
          redactDBInit = pkgs.writeText "redactdb-initscript" ''
            db = db.getSiblingDB("${redact_db_name}");
            db.createUser(
              {
                user: "${redact_db_user}",
                pwd: "${redact_db_password}",
                roles: [
                  { role: "dbOwner", db: "${redact_db_name}" }
                ]
              }
            );
          '';
        in
        ''
          {
            containers."${server_db_container_name}" = {
              ephemeral = true;
              privateNetwork = true;
              hostAddress = \"10.250.0.1\";
              localAddress = \"10.250.0.2\";

              config = { pkgs, ... }: {
                networking.useDHCP = false;
                networking.firewall.allowedTCPPorts = [ ${builtins.toString server_db_port} ];

                services.postgresql = {
                  enable = true;
                  enableTCPIP = true;
                  port = ${builtins.toString server_db_port};
                  authentication = pkgs.lib.mkForce '''
                    # Generate file, do not edit!
                    # TYPE    DATABASE    USER    ADDRESS         METHOD
                    local     all         all                     trust
                    host      all         all     10.0.0.1/8      md5
                    host      all         all     ::1/128         md5
                  ''';
                  initialScript = ${serverDBInit};
                };
              };
            };

            containers."${redact_db_container_name}" = {
              ephemeral = true;
              privateNetwork = true;
              hostAddress = \"10.250.0.1\";
              localAddress = \"${redact_db_local_addr}\";
              additionalCapabilities = [ \"cap_ipc_lock\" ];

              config = { pkgs, ... }: {
                networking.useDHCP = false;
                networking.firewall.allowedTCPPorts = [ ${builtins.toString redact_db_port} ];
                nixpkgs.config.allowUnfree = true;

                services.mongodb = {
                  package = pkgs.mongodb-4_2;
                  bind_ip = \"0.0.0.0\";
                  enable = true;
                  enableAuth = true;
                  port = ${builtins.toString redact_db_port};
                  initialRootPassword = \"${redact_db_root_password}\";
                  initialScript = ${redactDBInit};
                };
              };
            };
          }
        '';
    in
    rec {
      devShell."${system}" = pkgs.mkShell {
        nativeBuildInputs = with pkgs;
          [
            # build inputs
            pkg-config
            openssl

            # encrypted config
            sops

            # rust
            (rust-bin.stable.latest.default.override {
              targets = [ "wasm32-unknown-unknown" "x86_64-unknown-linux-gnu" ];
            })

            # Rust Cargo tools
            cargo
            cargo-edit
            cargo-audit
            cargo-tarpaulin

            # Frontend builder
            trunk

            # database
            sqlx-cli
            postgresql # (for psql command)

            # Server logs formatter
            bunyan-rs
            mongodb

          ];

        shellHook =
          let
            closeScript = pkgs.writeShellScriptBin "closescript" ''
              extra-container destroy "${server_db_container_name}"
              extra-container destroy "${redact_db_container_name}"
              pkill redact-store
              pkill redact-client
            '';

            waitRun = pkgs.writeShellScriptBin "waitscript" ''
              exit_code="7"
              until [ $exit_code != "7" ]
              do
                curl --silent "https://localhost:${builtins.toString redact_store_port}"
                exit_code=$?
                echo "Waiting for redact store to start"
                sleep 2
              done
            '';
          in
          ''
            set -m
            rm -rf ./redact-store/tls/server/
            rm -rf ./redact-client/tls/server/
            rm -rf ./redact-client/certs
            rm -rf ./redact-client/keys
            echo ${"'" + redactStoreConfigFile + "'"} > ./redact-store/config/config.yaml
            echo ${"'" + redactClientConfigFile + "'"} > ./redact-client/config/config.yaml
            echo ${"'" + sqlsConfigFile + "'"} > ./daysquare-backend/config.yml
            echo ${"'" + backendConfigFile + "'"} > ./daysquare-backend/configuration.yaml

            # Start containers
            extra-container create -E "${containers}" --nixos-path "${mongofix}/nixos" --start
            trap ${closeScript}/bin/closescript EXIT
            sleep 1

            sqlx database create
            sqlx migrate --source ./backend/migrations run

            # Start redact store and client
            pushd ./redact-store
            cargo run &>../redactstore-log.txt &
            ${waitRun}/bin/waitscript
            mkdir -p ../redact-client/${redact_client_tls_ca_folder}
            cp ${redact_store_tls_ca_path} ../redact-client/${redact_client_tls_ca_path}
            popd
            pushd ./redact-client
            cargo run &>../redactclient-log.txt &
            popd
          '';

        DATABASE_URL = "postgres://${server_db_user}:${server_db_password}@${server_db_container_name}:${builtins.toString server_db_port}/${server_db_name}";
        MONGO_URL = redact_db_conn_string;
        PGHOST = server_db_container_name;
        PGUSER = server_db_user;
        PGPORT = server_db_port;
        PGDATABASE = server_db_name;
      };
    };
}


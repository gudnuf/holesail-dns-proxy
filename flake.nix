{
  description = "Forward proxy for Holesail to DNS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # node2nix generated Nix expressions for holesail
        nodePackages = import ./node-packages { inherit pkgs; };

        # These will be mapped to the nginx.conf
        domainsToPorts = [
          { domain = "domain1.com"; port = "3338"; }
          { domain = "domain2.com"; port = "3339"; }
        ];

        # Write Nginx config to a file
        nginxConfigFile = pkgs.writeTextFile {
          name = "nginx.conf";
          text = ''
            events {
              worker_connections 1024;
            }

            http {
              log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                              '$status $body_bytes_sent "$http_referer" '
                              '"$http_user_agent" "$http_x_forwarded_for"';

              access_log LOG_PATH/access.log main;
              error_log LOG_PATH/error.log warn;

              ${builtins.concatStringsSep "\n" (map (d: ''
                server {
                  listen 8080;  # non privileged port
                  server_name ${d.domain};

                  location / {
                    proxy_pass http://localhost:${d.port};
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                  }
                }
              '') domainsToPorts)}
            }

            # Specify custom PID file location
            pid LOG_PATH/nginx.pid;
          '';
        };

      in
      {
        packages = {
          nginx = pkgs.nginx;
          holesail = nodePackages.package;
        };

        defaultPackage = self.packages.${system}.holesail;
        defaultApp = self.apps.${system}.nginx;

        # Define apps for running nginx and holesail
        apps = {
          nginx = {
            type = "app";
            program = toString (pkgs.writeShellScript "run-nginx" ''
              # Get the current working directory
              current_dir=$(pwd)

              # Ensure the logs directory exists and is writable
              mkdir -p "$current_dir/logs"
              chmod 777 "$current_dir/logs"

              # Replace LOG_PATH in the nginx config file with the absolute logs path
              sed "s|LOG_PATH|$current_dir/logs|g" ${nginxConfigFile} > "$current_dir/nginx.conf"

              # Log the paths being used for debugging
              echo "Using nginx config at: $current_dir/nginx.conf"
              echo "Logs will be written to: $current_dir/logs"

              # Run Nginx with the modified config, prefix, and error log file
              exec ${pkgs.nginx}/bin/nginx -c "$current_dir/nginx.conf" -p "$current_dir" -e "$current_dir/logs/error.log"
            '');
          };
          holesail = {
            type = "app";
            program = toString (pkgs.writeShellScript "run-holesail" ''
              exec ${self.packages.${system}.holesail}/bin/holesail
            '');
          };
        };

        

        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.nginx
            self.packages.${system}.holesail
          ];
        };
      }
    );
}

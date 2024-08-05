{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        };

        devShellPackages = with pkgs; [
          gcc # for any python package that requires compilation
          poetry
          zlib # for numpy
          ngrok
          redis
          jq
          curl
          coreutils
          pkg-config
          systemd
        ];

        development = true;
      in
      rec {
        devShell = pkgs.mkShell {
          buildInputs = devShellPackages;
          shellHook = if development then (with pkgs; ''
            export LD_LIBRARY_PATH="${stdenv.cc.cc.lib}/lib"

            # Prompt to delete log files with a 5-second timeout
            echo "Clear *.log files? (Y/n)"
            read -t 5 -n 1 -r
            echo    # Move to a new line
            if [[ $REPLY =~ ^[Nn]$ ]]; then
              echo "Retaining *.log files..."
            else
              echo "Deleting *.log files..."
              find . -name "*.log" -type f -delete
            fi

            redis-server > >(tee -a redis_server.log) 2>&1 &
            REDIS_PID=$!

            poetry run rq worker --with-scheduler > >(tee -a rq_worker.log) 2>&1 &
            RQ_PID=$!

            ngrok_url=$(ngrok http 8000 --log=stdout > /dev/null & sleep 2 && curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
            NGROK_PID=$!
            
            export NGROK_URL=$ngrok_url
            
            echo "REDIS_PID: $REDIS_PID"
            echo "RQ_PID: $RQ_PID"
            echo "NGROK_PID: $NGROK_PID"
            echo "NGROK_URL: $NGROK_URL"

            trap 'kill $NGROK_PID $RQ_PID && sleep 1 && kill $REDIS_PID && pkill -f ngrok' EXIT
          '') else "";
        };
      }
    );
}
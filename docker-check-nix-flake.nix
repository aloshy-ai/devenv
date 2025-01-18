{
  pkgs,
  system,
}: let
  dockerManageScript = pkgs.writeScriptBin "docker-manage" ''
    #!${pkgs.bash}/bin/bash

    # Spinner function
    spinner() {
      local pid=$1
      local delay=0.1
      local spinstr='|/-\'
      while ps a | awk '{print $1}' | grep -q "$pid"; do
        local temp=''${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp''${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
      done
      printf "    \b\b\b\b"
    }

    is_docker_running() {
      if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
          return 0
        fi
      fi
      return 1
    }

    start_docker() {
      echo "Starting Docker daemon..."

      # Detect the operating system
      if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open --background -a Docker && {
          # Wait for Docker to start
          local max_attempts=30
          local attempt=1
          while [ $attempt -le $max_attempts ]; do
            if is_docker_running; then
              echo "Docker daemon successfully started"
              return 0
            fi
            sleep 1
            ((attempt++))
          done
          echo "Failed to start Docker daemon after $max_attempts seconds"
          return 1
        }
      elif command -v systemctl >/dev/null 2>&1; then
        # Linux with systemd
        systemctl start docker &
        spinner $!

        # Wait for Docker to start
        local max_attempts=30
        local attempt=1
        while [ $attempt -le $max_attempts ]; do
          if systemctl is-active --quiet docker; then
            echo "Docker daemon successfully started"
            return 0
          fi
          sleep 1
          ((attempt++))
        done
        echo "Failed to start Docker daemon after $max_attempts seconds"
        return 1
      else
        echo "Unsupported system: cannot detect systemd or macOS"
        return 1
      fi
    }

    check_docker() {
      if ! command -v docker >/dev/null 2>&1; then
        echo "Docker is not installed"
        return 2
      fi

      if is_docker_running; then
        echo "Docker daemon is running"
        return 0
      else
        echo "Docker daemon is not running"
        read -p "Would you like to start it? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          start_docker
          return $?
        fi
        return 1
      fi
    }

    check_docker
  '';
in {
  inherit dockerManageScript;
}


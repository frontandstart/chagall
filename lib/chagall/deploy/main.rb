require 'securerandom'
require_relative 'settings'

module Chagall
  module Deploy
    class Main

      def initialize(argv, dry_run: false)
        Settings.configure(argv, dry_run: dry_run)

        run unless dry_run
      end

      def run
        Settings[:tag] ||= generate_commit_sha
        setup_server
        
        if Settings[:remote]
          remote_build
        else
          local_build_and_load
        end
        
        verify_image
        update_compose
      end

      private

      def generate_commit_sha
        SecureRandom.hex(16)
      end

      def project_folder_path
        "chagall/#{Settings[:name]}"
      end

      def docker_image_tar_path
        "#{project_folder_path}/#{Settings[:tag]}.tar"
      end

      def setup_server
        puts "Setting up server directory..."
        system("ssh #{Settings[:server]} 'mkdir -p #{project_folder_path}'") or
          raise "Failed to create project directory on server"
      end

      def local_build_and_load
        puts "Building image locally and loading to server..."
        build_cmd = [
          "docker buildx build",
          "--cache-from=type=local,src=tmp/.buildx-cache",
          "--cache-to=type=local,dest=tmp/.buildx-cache-new,mode=max",
          "--output=type=tar,dest=-",
          "--platform #{Settings[:platform]}",
          "-t #{Settings[:name]}:#{Settings[:tag]}",
          "--target production"
        ]
        
        build_cmd << "--build-arg #{Settings[:build_args]}" if Settings[:build_args]
        build_cmd << "-f Dockerfile ."
        
        full_cmd = "#{build_cmd.join(' ')} | ssh #{Settings[:server]} 'docker image load'"
        system(full_cmd) or raise "Failed to build and load Docker image"
        
        # Retag if platform-specific tag was created
        retag_cmd = "ssh #{Settings[:server]} 'docker tag #{Settings[:name]}-#{Settings[:platform]}:#{Settings[:tag]} #{Settings[:name]}:#{Settings[:tag]}'"
        system(retag_cmd)
      end

      def remote_build
        puts "Building image remotely on server..."
        build_cmd = [
          "docker build",
          "--platform #{Settings[:platform]}",
          "-t #{Settings[:name]}:#{Settings[:tag]}",
          "--target production"
        ]
        
        build_cmd << "--build-arg #{Settings[:build_args]}" if Settings[:build_args]
        build_cmd << "-f Dockerfile ."
        
        system("ssh #{Settings[:server]} '#{build_cmd.join(' ')}'") or
          raise "Failed to build Docker image on server"
      end

      def verify_image
        puts "Verifying image on server..."
        check_cmd = "docker images --filter=reference=#{Settings[:name]}:#{Settings[:tag]} --format '{{.ID}}' | grep ."
        system("ssh #{Settings[:server]} '#{check_cmd}'") or
          raise "Docker image #{Settings[:name]}:#{Settings[:tag]} not found on #{Settings[:server]}"
      end

      def update_compose
        puts "Updating compose configuration..."
        compose_cmd = ["docker compose"]
        Settings[:compose_files].each do |file|
          compose_cmd << "-f #{file}"
        end
        compose_cmd << "up -d"
        
        system("ssh #{Settings[:server]} '#{compose_cmd.join(' ')}'") or
          raise "Failed to update compose services"
      end
    end
  end
end 
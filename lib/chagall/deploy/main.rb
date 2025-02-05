require_relative 'settings'

module Chagall
  module Deploy
    class Main
      def initialize(argv, dry_run: false)
        Settings.configure(argv)

        run unless dry_run
      end

      def run
        setup_server
        build or raise 'Failed to build Docker image'
        verify_image or raise 'Failed to verify Docker image'
        update_compose_files
        deploy
      end

      def setup_server
        puts 'Setting up server directory...'
        ssh_cmd("mkdir -p #{project_folder_path}") or
          raise 'Failed to create project directory on server'
      end

      def build
        if Settings[:remote]
          ssh_cmd(build_cmd)
        else
          ssh_cmd("#{build_cmd} | docker image load")
        end
      end

      def verify_image
        puts 'Verifying image on server...'

        check_cmd = "docker images --filter=reference=#{Settings[:name]}:#{Settings[:tag]} --format '{{.ID}}' | grep ."

        ssh_cmd(check_cmd) or
          raise "Docker image #{Settings[:name]}:#{Settings[:tag]} not found on #{Settings[:server]}"
      end

      def tag_as_production
        puts "Tagging Docker #{Settings[:name]}:#{Settings[:tag]} image as production..."

        command = "docker tag #{Settings[:name]}:#{Settings[:tag]} #{Settings[:name]}:production"
        ssh_cmd(command) or raise 'Failed to tag Docker image'
      end

      def build_cmd
        cmd = [
          'docker build',
          "  --cache-from=type=local,src=#{Settings.options.cache_path}/.buildx-cache",
          "  --cache-to=type=local,dest=#{Settings.options.cache_path}/.buildx-cache-new,mode=max",
          "  --platform #{Settings.options.platform}",
          "  --tag #{Settings.options.name}:#{Settings.options.tag}",
          "  --target #{Settings.options.target}"
        ]

        cmd << if Settings[:remote]
                 '  --load'
               else
                 '  --output=type=tar,dest=-'
               end

        cmd << "--build-arg #{Settings.options.build_args}" if Settings.options.build_args
        cmd << "-f #{Settings.options.dockerfile} #{Settings.options.context}"

        cmd.join("\n")
      end

      def update_compose_files
        puts 'Updating compose configuration files on remote server...'

        Settings[:compose_files].each do |file|
          remote_destination = "#{project_folder_path}/#{File.basename(file)}"
          copy_file(file, remote_destination)
        end

        puts 'Updating compose services...'
        compose_cmd = ['docker compose']
        # Use the remote file paths for docker compose command
        Settings[:compose_files].each do |f ile|
          remote_file = "#{project_folder_path}/#{File.basename(file)}"
          compose_cmd << "-f #{remote_file}"
        end
        compose_cmd << 'up -d'

        ssh_cmd(compose_cmd.join(' ')) or raise 'Failed to update compose services'
      end

      def copy_file(local_file, remote_destination)
        puts "Copying #{local_file} to #{Settings[:server]}:#{remote_destination}..."
        system("scp #{local_file} #{Settings[:server]}:#{remote_destination}") or
          raise "Failed to copy #{local_file} to server"
      end

      def project_folder_path
        "chagall/#{Settings[:name]}"
      end

      def docker_image_tar_path
        "#{project_folder_path}/#{Settings[:tag]}.tar"
      end

      def ssh_cmd(cmd)
        system "ssh #{Settings[:server]} '#{cmd}'"
      end
    end
  end
end

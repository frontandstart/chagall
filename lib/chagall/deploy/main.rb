require_relative 'settings'

module Chagall
  module Deploy
    class Main
      def initialize(argv)
        Settings.configure(argv)

        run
      end

      def run
        setup_server(run: Settings[:dry_run])
        build(run: Settings[:dry_run]) or raise 'Failed to build Docker image'
        verify_image(run: Settings[:dry_run]) or raise 'Failed to verify Docker image'
        update_compose_files(run: Settings[:dry_run])
        deploy_compose_files(run: Settings[:dry_run])
      end

      def setup_server
        puts 'Setting up server directory...'
        command = "mkdir -p #{project_folder_path}"
        if Settings[:dry_run]
          puts "DRY RUN: #{command}"
        else
          ssh_cmd(command) or raise 'Failed to create project directory on server'
        end
      end

      def build
        command = Settings[:remote] ? ssh_cmd(build_cmd) : "#{build_cmd} | docker image load"
        if Settings[:dry_run]
          puts "DRY RUN: #{command}"
        else
          ssh_cmd(command)
        end
      end

      def verify_image
        puts 'Verifying image on server...'

        check_cmd = "docker images --filter=reference=#{Settings[:name]}:#{Settings[:tag]} --format '{{.ID}}' | grep ."
        if Settings[:dry_run]
          puts "DRY RUN: #{check_cmd}"
        else
          ssh_cmd(check_cmd) or
            raise "Docker image #{Settings[:name]}:#{Settings[:tag]} not found on #{Settings[:server]}"
        end
      end

      def tag_as_production
        puts "Tagging Docker #{Settings[:name]}:#{Settings[:tag]} image as production..."

        command = "docker tag #{Settings[:name]}:#{Settings[:tag]} #{Settings[:name]}:production"
        ssh_cmd(command) or raise 'Failed to tag Docker image'
      end

      def build_cmd
        cmd = [
          'docker build',
          "  --cache-from=#{Settings[:cache_from]}",
          "  --cache-to=#{Settings[:cache_to]}",
          "  --platform #{Settings[:platform]}",
          "  --tag #{Settings[:docker_image_label]}",
          "  --target #{Settings[:target]}",
          "  --file #{Settings[:dockerfile]}",
          "  --context #{Settings[:context]}"
        ]

        cmd << if Settings[:remote]
                 '  --load'
               else
                 '  --output=type=tar,dest=-'
               end

        cmd << "  #{Settings[:context]}"

        cmd.join("\n")
      end

      def update_compose_files
        puts 'Updating compose configuration files on remote server...'

        Settings[:compose_files].each do |file|
          remote_destination = "#{Settings[:projects_folder]}/#{File.basename(file)}"
          copy_file(file, remote_destination)
        end
      end

      def deploy_compose_files
        puts 'Updating compose services...'
        compose_cmd = ['docker compose']

        # Use the remote file paths for docker compose command
        Settings[:compose_files].each do |file|
          remote_file = "#{Settings[:projects_folder]}/#{File.basename(file)}"
          compose_cmd << "-f #{remote_file}"
        end
        compose_cmd << 'up -d'

        ssh_cmd(compose_cmd.join(' ')) or raise 'Failed to update compose services'
      end

      def copy_file(local_file, remote_destination)
        puts "Copying #{local_file} to #{Settings[:server]}:#{remote_destination}..."
        command = "scp #{local_file} #{Settings[:server]}:#{remote_destination}"
        if Settings[:dry_run]
          puts "DRY RUN: #{command}"
          true
        else
          system(command) or raise "Failed to copy #{local_file} to server"
        end
      end

      def ssh_cmd(cmd)
        full_cmd = "ssh #{Settings[:server]} '#{cmd}'"
        system(full_cmd)
      end
    end
  end
end

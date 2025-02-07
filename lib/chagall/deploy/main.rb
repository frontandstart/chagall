require_relative 'settings'

module Chagall
  module Deploy
    class Main
      def initialize(argv)
        Settings.configure(argv)

        run
      end

      def run
        setup_server
        build
        verify_image
        update_compose_files
        deploy
      end

      def setup_server
        puts 'Setting up server directory...'
        command = "echo 'Mock: Setting up server docker & directory...'"
        execute(command)
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
          "  --cache-from=#{Settings.options[:cache_from]}",
          "  --cache-to=#{Settings.options[:cache_to]}",
          "  --platform #{Settings.options[:platform]}",
          "  --tag #{Settings.instance.tag}",
          "  --target #{Settings.options[:target]}",
          "  --file #{Settings.options[:dockerfile]}",
          Settings.instanceo.context
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
        deploy_command = ['docker compose']

        # Use the remote file paths for docker compose command
        Settings[:compose_files].each do |file|
          remote_file = "#{Settings[:projects_folder]}/#{File.basename(file)}"
          deploy_command << "-f #{remote_file}"
        end
        deploy_command << 'up -d'

        execute(deploy_command.join(' '),
                directory: Settings[:projects_folder]) or raise 'Failed to update compose services'
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

      def deploy
        tag_as_production
        deploy_compose_files
      end

      def execute(command, directory: nil, force: false)
        command = if directory
                    "ssh #{Settings[:server]} 'cd #{directory} && #{command}'"
                  else
                    "ssh #{Settings[:server]} '#{command}'"
                  end

        if Settings[:dry_run] && !force
          puts "DRY RUN: #{command}"
        else
          system(command)
        end
      end
    end
  end
end

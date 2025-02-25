require_relative 'settings'

module Chagall
  module Deploy
    class Main
      def initialize(argv)
        Settings.configure(argv)

        p Settings.options
        # binding.pry
        run
      rescue StandardError => e
        puts "Deployment failed: #{e.message}"
        puts e.backtrace
        exit 1
      end

      def run
        setup_server
        build
        # rotate_cache
        # verify_image
        # update_compose_files
        # deploy
      end

      def setup_server
        puts 'Setting up server directory...'
        command = "mkdir -p #{Settings[:projects_folder]}/#{Settings[:name]}"
        ssh_execute(command)
      end

      def build
        p 'DEBUG: build_cmd'
        puts build_cmd
        if Settings[:dry_run]
          puts "DRY RUN: #{build_cmd}"
        else
          system(build_cmd)
        end
      end

      def load_image_to_server
        return

        system "docker save #{Settings.instance.tag} | #{ssh_execute('docker load')}"
      end

      def rotate_cache
        system("rm -rf #{Settings[:cache_from]}")
        system("mv #{Settings[:cache_to]} #{Settings[:cache_from]}")
      end

      def verify_image
        puts 'Verifying image on server...'

        check_cmd = "docker images --filter=reference=#{Settings[:name]}:#{Settings[:tag]} --format '{{.ID}}' | grep ."
        if Settings[:dry_run]
          puts "DRY RUN: #{check_cmd}"
        else
          ssh_execute(check_cmd) or
            raise "Docker image #{Settings[:name]}:#{Settings[:tag]} not found on #{Settings[:server]}"
        end
      end

      def tag_as_production
        puts "Tagging Docker #{Settings[:name]}:#{Settings[:tag]} image as production..."

        command = "docker tag #{Settings[:name]}:#{Settings[:tag]} #{Settings[:name]}:production"
        ssh_execute(command) or raise 'Failed to tag Docker image'
      end

      def build_cmd
        args = [
          "--cache-from #{Settings[:cache_from]}",
          "--cache-to #{Settings[:cache_to]}",
          "--platform #{Settings[:platform]}",
          "--tag #{Settings.instance.tag}",
          "--target #{Settings[:target]}",
          "--file #{Settings[:dockerfile]}"
        ]

        if Settings[:remote]
          args.push('--load')
        else
          args.push('--output type=docker,dest=-')
        end

        args.push(Settings[:context])

        args = args.map { |arg| "    #{arg}" }
                   .join("\\\n")

        cmd =  "docker build \\\n#{args}"
        if Settings[:remote]
          ssh_command(cmd)
        else
          "#{cmd} | #{ssh_command('docker load')}"
        end
      end

      def update_compose_files
        puts 'Updating compose configuration files on remote server...'

        # binding
        p "Settings[:compose_files] #{Settings[:compose_files]}"

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

        ssh_execute(deploy_command.join(' '),
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

      def ssh_command(command, directory: nil)
        if directory
          "ssh #{Settings[:ssh_args]} #{Settings[:server]} 'cd #{directory} && #{command}'"
        else
          "ssh #{Settings[:ssh_args]} #{Settings[:server]} '#{command}'"
        end
      end

      def ssh_execute(command, directory: nil, force: false)
        command = if directory
                    "ssh #{Settings[:ssh_args]} #{Settings[:server]} 'cd #{directory} && #{command}'"
                  else
                    "ssh #{Settings[:ssh_args]} #{Settings[:server]} '#{command}'"
                  end

        p "SSH: debug #{command}"
        if Settings[:dry_run] && !force
          puts "DRY RUN: #{command}"
        else
          system(command)
        end
      end
    end
  end
end

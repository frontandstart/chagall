require_relative 'settings'
require 'digest'

module Chagall
  module Deploy
    class Main
      def initialize(argv)
        Settings.configure(argv)

        run
      rescue StandardError => e
        puts "Deployment failed: #{e.message}"
        puts e.backtrace
        exit 1
      end

      def run
        setup_server

        # Check if image exists and compose files are up to date
        if verify_image(check_only: true)
          puts "Image #{Settings.instance.image_tag} exists and compose files are up to date"
          puts 'Proceeding with deployment...'
          deploy
          return
        end

        build
        rotate_cache
        update_compose_files
        verify_image
        deploy
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

      def rotate_cache
        system("rm -rf #{Settings[:cache_from]}")
        system("mv #{Settings[:cache_to]} #{Settings[:cache_from]}")
      end

      def verify_image(check_only: false)
        puts 'Verifying image on server...'

        check_cmd = "docker images --filter=reference=#{Settings.instance.image_tag} --format '{{.ID}}' | grep ."

        # Use backticks to capture output instead of system
        output = `#{ssh_command(check_cmd)} 2>/dev/null`.strip
        exists = !output.empty?

        if check_only
          puts "Image #{exists ? 'found' : 'not found'}: #{Settings.instance.image_tag}"
          return exists
        end

        raise "Docker image #{Settings.instance.image_tag} not found on #{Settings[:server]}" unless exists

        true
      end

      def verify_compose_files
        puts 'Verifying compose files on server...'

        Settings[:compose_files].all? do |file|
          remote_file = "#{Settings[:projects_folder]}/#{File.basename(file)}"
          local_md5 = ::Digest::MD5.file(file).hexdigest

          check_cmd = "md5sum #{remote_file} 2>/dev/null | cut -d' ' -f1"
          remote_md5 = `#{ssh_command(check_cmd)}`.strip
          local_md5 == remote_md5
        end
      end

      def tag_as_production
        puts "Tagging Docker #{Settings.instance.image_tag} image as production..."

        command = "docker tag #{Settings.instance.image_tag} #{Settings[:name]}:production"
        ssh_execute(command) or raise 'Failed to tag Docker image'
      end

      def build_cmd
        args = [
          "--cache-from type=local,src=#{Settings[:cache_from]}",
          "--cache-to type=local,dest=#{Settings[:cache_to]},mode=max",
          "--platform #{Settings[:platform]}",
          "--tag #{Settings.instance.image_tag}",
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

        Settings[:compose_files].each do |file|
          remote_destination = "#{Settings.instance.project_folder_path}/#{File.basename(file)}"
          copy_file(file, remote_destination)
        end
      end

      def deploy_compose_files
        puts 'Updating compose services...'
        deploy_command = ['docker compose']

        # Use the remote file paths for docker compose command

        Settings[:compose_files].each do |file|
          deploy_command << "-f #{File.basename(file)}"
        end
        deploy_command << 'up -d'

        ssh_execute(deploy_command.join(' '),
                    directory: Settings.instance.project_folder_path) or raise 'Failed to update compose services'
      end

      def copy_file(local_file, remote_destination)
        puts "Copying #{local_file} to #{Settings[:server]}:#{remote_destination}..."
        command = "scp #{local_file} #{Settings[:server]}:#{remote_destination}"

        system(command) or raise "Failed to copy #{local_file} to server"
      end

      def deploy
        tag_as_production
        update_compose_files
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

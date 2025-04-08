# frozen_string_literal: true

require 'English'
require_relative '../settings'
require_relative '../ssh'
require 'digest'
require 'benchmark'
require 'yaml'

module Chagall
  module Deploy
    class Main < Base
      attr_reader :total_time

      def initialize(argv)
        super()
        @interrupted = false
        @total_time = 0.0
        setup_signal_handlers

        Time.now

        t('Checking uncommitted changes') { check_uncommit_changes } unless Settings[:skip_uncommit_check]
        t('Check image or build') { check_image_or_build }
        t('tag as production') { tag_as_production }
        t('update compose files') { update_compose_files }
        t('deploy compose files') { deploy_compose_files }
        t('rotate release') { rotate_releases }

        print_total_time
      rescue Interrupt
        logger.info "\nDeployment interrupted by user"
        print_total_time
        cleanup_and_exit
      rescue StandardError => e
        logger.error "Deployment failed: #{e.message}"
        logger.debug e.backtrace.join("\n") if ENV['DEBUG']
        print_total_time
        exit 1
      end

      def check_image_or_build
        image_exists = verify_image(check_only: true)

        if image_exists
          logger.info "Image #{Settings.instance.image_tag} exists and compose files are up to date"
          return
        end

        t('Building image') { build }
        t('Rotating cache') { rotate_cache }
        t('Verifying image') { verify_image }
      end

      def setup_signal_handlers
        # Handle CTRL+C (SIGINT)
        Signal.trap('INT') do
          @interrupted = true
          puts "\nReceived interrupt signal. Cleaning up..."
          cleanup_and_exit
        end

        # Handle SIGTERM
        Signal.trap('TERM') do
          @interrupted = true
          puts "\nReceived termination signal. Cleaning up..."
          cleanup_and_exit
        end
      end

      def cleanup_and_exit
        puts 'Cleaning up...'
        # Add any cleanup tasks here
        exit 1
      end

      def check_interrupted
        return unless @interrupted

        puts 'Operation interrupted by user'
        cleanup_and_exit
      end

      private

      def print_total_time
        logger.info "Total execution time: #{format('%.2f', @total_time)}s"
      end

      def t(title)
        logger.info "[#{title.upcase}]..."
        start_time = Time.now
        result = yield
        duration = Time.now - start_time
        @total_time += duration
        logger.info " done #{'%.2f' % duration}s"
        check_interrupted
        result
      rescue StandardError
        duration = Time.now - start_time
        @total_time += duration
        logger.error " failed #{format('%.2f', duration)}s"
        raise
      end

      def check_uncommit_changes
        status = `git status --porcelain`.strip
        raise 'Uncommitted changes found. Commit first' unless status.empty?
      end

      def setup_server
        SetupServer.new(ssh, logger).setup
      end

      def build
        logger.debug "Building #{Settings.instance.image_tag} image and load to server"
        system(build_cmd)
      end

      def rotate_cache
        system("rm -rf #{Settings[:cache_from]}")
        system("mv #{Settings[:cache_to]} #{Settings[:cache_from]}")
      end

      def verify_image(check_only: false)
        logger.debug 'Verifying image on server...'

        check_cmd = "docker images --filter=reference=#{Settings.instance.image_tag} --format '{{.ID}}' | grep ."

        # Use backticks to capture output instead of system
        output = `#{ssh.command(check_cmd)} 2>/dev/null`.strip
        exists = !output.empty?

        if check_only
          logger.debug "Image #{exists ? 'found' : 'not found'}: #{Settings.instance.image_tag}"
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
          remote_md5 = `#{ssh.command(check_cmd)}`.strip
          local_md5 == remote_md5
        end
      end

      def tag_as_production
        logger.debug "Tagging Docker #{Settings.instance.image_tag} image as production..."

        command = "docker tag #{Settings.instance.image_tag} #{Settings[:name]}:production"
        ssh.execute(command) or raise 'Failed to tag Docker image'
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
          ssh.command(cmd)
        else
          "#{cmd} | #{ssh.command('docker load')}"
        end
      end

      def update_compose_files
        logger.debug 'Updating compose configuration files on remote server...'

        Settings[:compose_files].each do |file|
          remote_destination = "#{Settings.instance.project_folder_path}/#{File.basename(file)}"
          copy_file(file, remote_destination)
        end
      end

      def deploy_compose_files
        logger.debug 'Updating compose services...'
        deploy_command = ['docker compose']

        # Use the remote file paths for docker compose command
        Settings[:compose_files].each do |file|
          deploy_command << "-f #{File.basename(file)}"
        end
        deploy_command << 'up -d'

        ssh.execute(deploy_command.join(' '),
                    directory: Settings.instance.project_folder_path) or raise 'Failed to update compose services'
      end

      def copy_file(local_file, remote_destination)
        logger.debug "Copying #{local_file} to #{Settings[:server]}:#{remote_destination}..."
        command = "scp #{local_file} #{Settings[:server]}:#{remote_destination}"

        system(command) or raise "Failed to copy #{local_file} to server"
      end

      def rotate_releases
        logger.debug 'Rotating releases...'
        release_folder = "#{Settings.instance.project_folder_path}/releases"
        release_file = "#{release_folder}/#{Settings[:release]}"

        # Create releases directory if it doesn't exist
        ssh.execute("mkdir -p #{release_folder}")

        # Save current release
        ssh.execute("touch #{release_file}")

        # Get list of releases sorted by modification time (newest first)
        list_cmd = "ls -t #{release_folder}"
        releases = `#{ssh.command(list_cmd)}`.strip.split("\n")

        # Keep only the last N releases
        logger.info "releases #{releases.length}"
        return unless releases.length > Settings[:keep_releases]

        releases_to_remove = releases[Settings[:keep_releases]..]

        # Remove old release files
        releases_to_remove.each do |release|
          ssh.execute("rm #{release_folder}/#{release}")

          # Remove corresponding Docker image
          image = "#{Settings[:name]}:#{release}"
          logger.info "Removing old Docker image: #{image}"
          ssh.execute("docker rmi #{image} || true") # Use || true to prevent failure if image is already removed
        end
      end

      def system(*args)
        result = super
        raise "Command failed with exit code #{$CHILD_STATUS.exitstatus}: #{args.join(' ')}" unless result

        result
      end
    end
  end
end

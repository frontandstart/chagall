# frozen_string_literal: true

require "spec_helper"
require "chagall/deploy"
require "chagall/settings"

RSpec.describe Chagall::Deploy do
  let(:settings) { instance_double(Chagall::Settings, project_folder_path: "/app", image_tag: "myapp:latest") }
  let(:ssh) { instance_double("SSH") }
  let(:compose_files) { ["compose.yaml", "compose.prod.yaml"] }
  let(:compose_content) do
    {
      "services" => {
        "app" => {
          "build" => {
            "context" => ".",
            "dockerfile" => "Dockerfile",
            "args" => {
              "RUBY_VERSION" => "3.2.0"
            }
          }
        },
        "worker" => {
          "build" => {
            "context" => "./worker",
            "dockerfile" => "worker/Dockerfile"
          }
        },
        "redis" => {
          "image" => "redis:latest"
        }
      }
    }
  end

  before do
    allow(Chagall::Settings).to receive(:instance).and_return(settings)
    allow(Chagall::Settings).to receive(:[]).and_call_original
    allow(Chagall::Settings).to receive(:[]).with(:compose_files).and_return(compose_files)
    allow(Chagall::Settings).to receive(:[]).with(:name).and_return("myapp")
    allow(Chagall::Settings).to receive(:[]).with(:platform).and_return("linux/x86_64")
    allow(Chagall::Settings).to receive(:[]).with(:cache_from).and_return("tmp/.buildx-cache")
    allow(Chagall::Settings).to receive(:[]).with(:cache_to).and_return("tmp/.buildx-cache-new")
    allow(Chagall::Settings).to receive(:[]).with(:remote).and_return(false)
    allow(Chagall::Settings).to receive(:[]).with(:target).and_return("production")
    allow(Chagall::Settings).to receive(:[]).with(:release).and_return("abc123")
    allow(Chagall::Settings).to receive(:[]).with(:dockerfile).and_return("Dockerfile")
    allow(Chagall::Settings).to receive(:[]).with(:docker_context).and_return(".")
    allow(Chagall::Settings).to receive(:[]).with(:server).and_return("example.com")
    allow_any_instance_of(described_class).to receive(:ssh).and_return(ssh)
    allow(YAML).to receive(:load_file).with(any_args).and_return(compose_content)
    allow(FileUtils).to receive(:mkdir_p)
  end

  describe "#cleanup_and_exit" do
    it "removes the temporary tar file and exits" do
      allow(File).to receive(:exist?).with("tmp/abc123.tar").and_return(true)
      expect(FileUtils).to receive(:rm_f).with("tmp/abc123.tar")
      expect(subject).to receive(:exit).with(1)
      
      subject.cleanup_and_exit
    end
    
    it "does not attempt to remove the file if it doesn't exist" do
      allow(File).to receive(:exist?).with("tmp/abc123.tar").and_return(false)
      expect(FileUtils).not_to receive(:rm_f)
      expect(subject).to receive(:exit).with(1)
      
      subject.cleanup_and_exit
    end
  end

  describe "#get_services_to_build" do
    context "when no specific services are specified" do
      before do
        allow(Chagall::Settings).to receive(:[]).with(:services).and_return(nil)
      end

      it "returns all services with build configuration" do
        services = subject.send(:get_services_to_build)
        expect(services.keys).to match_array(["app", "worker"])
        expect(services["app"]["context"]).to eq(".")
        expect(services["worker"]["context"]).to eq("./worker")
      end
    end

    context "when specific services are specified" do
      before do
        allow(Chagall::Settings).to receive(:[]).with(:services).and_return(["app"])
      end

      it "returns only specified services with build configuration" do
        services = subject.send(:get_services_to_build)
        expect(services.keys).to match_array(["app"])
        expect(services["app"]["context"]).to eq(".")
      end
    end
  end

  describe "#build_cmd" do
    it "generates the correct docker build command for local image creation" do
      cmd = subject.send(:build_cmd)
      expect(cmd).to include("docker build")
      expect(cmd).to include("--cache-from type=local,src=tmp/.buildx-cache")
      expect(cmd).to include("--cache-to type=local,dest=tmp/.buildx-cache-new")
      expect(cmd).to include("--platform linux/x86_64")
      expect(cmd).to include("--target production")
      expect(cmd).to include("--file Dockerfile")
      expect(cmd).to include("--output type=docker,dest=tmp/abc123.tar")
      expect(cmd).to include("    .")
    end
  end

  describe "#upload_image_to_server" do
    it "creates the releases directory and uploads the tar file" do
      expect(ssh).to receive(:execute).with("mkdir -p /app/releases")
      expect(subject).to receive(:system).with("scp tmp/abc123.tar example.com:/app/releases/abc123.tar").and_return(true)
      
      subject.send(:upload_image_to_server)
    end
    
    it "raises an error if the upload fails" do
      expect(ssh).to receive(:execute).with("mkdir -p /app/releases")
      expect(subject).to receive(:system).with("scp tmp/abc123.tar example.com:/app/releases/abc123.tar").and_return(false)
      
      expect { subject.send(:upload_image_to_server) }.to raise_error("Failed to upload image to server")
    end
  end
  
  describe "#load_image_on_server" do
    it "loads the image on the server from the tar file" do
      expect(ssh).to receive(:execute).with("docker load < /app/releases/abc123.tar").and_return(true)
      
      subject.send(:load_image_on_server)
    end
    
    it "raises an error if loading the image fails" do
      expect(ssh).to receive(:execute).with("docker load < /app/releases/abc123.tar").and_return(false)
      
      expect { subject.send(:load_image_on_server) }.to raise_error("Failed to load image on server")
    end
  end

  describe "#rotate_releases" do
    before do
      allow(Chagall::Settings).to receive(:[]).with(:keep_releases).and_return(3)
      allow(subject).to receive(:`).with('').and_return("abc123\ndef456\nghi789\njkl012\n")
    end
    
    it "removes old release files and tar files" do
      expect(ssh).to receive(:execute).with("mkdir -p /app/releases")
      expect(ssh).to receive(:execute).with("touch /app/releases/abc123")
      expect(subject).to receive(:`).with(anything).and_return("abc123\ndef456\nghi789\njkl012\n")
      
      expect(ssh).to receive(:execute).with("rm /app/releases/jkl012")
      expect(ssh).to receive(:execute).with("rm /app/releases/jkl012.tar 2>/dev/null || true")
      expect(ssh).to receive(:execute).with("docker rmi myapp:jkl012 || true")
      
      subject.send(:rotate_releases)
    end
  end
end 
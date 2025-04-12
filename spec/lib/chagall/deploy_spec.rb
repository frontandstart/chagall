# frozen_string_literal: true

require "spec_helper"
require "chagall/deploy"
require "chagall/settings"

RSpec.describe Chagall::Deploy do
  let(:settings) { instance_double(Chagall::Settings, project_folder_path: "/app") }
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
    allow_any_instance_of(described_class).to receive(:ssh).and_return(ssh)
    allow(YAML).to receive(:load_file).with(any_args).and_return(compose_content)
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
    context "when building all services" do
      before do
        allow(Chagall::Settings).to receive(:[]).with(:services).and_return(nil)
      end

      it "generates build commands for all buildable services" do
        cmd = subject.send(:build_cmd)
        expect(cmd).to include("docker build")
        expect(cmd).to include("--file Dockerfile")
        expect(cmd).to include("--file worker/Dockerfile")
        expect(cmd).to include("--tag myapp:app")
        expect(cmd).to include("--tag myapp:worker")
        expect(cmd).to include("--build-arg RUBY_VERSION=3.2.0")
      end
    end

    context "when building specific services" do
      before do
        allow(Chagall::Settings).to receive(:[]).with(:services).and_return(["worker"])
      end

      it "generates build commands only for specified services" do
        cmd = subject.send(:build_cmd)
        expect(cmd).to include("docker build")
        expect(cmd).to include("--file worker/Dockerfile")
        expect(cmd).to include("--tag myapp:worker")
        expect(cmd).not_to include("--tag myapp:app")
        expect(cmd).not_to include("--build-arg RUBY_VERSION=3.2.0")
      end
    end
  end
end 
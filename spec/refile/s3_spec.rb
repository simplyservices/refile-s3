require "refile/spec_helper"
require "refile/s3"

WebMock.allow_net_connect!

RSpec.describe Refile::S3 do
  context "with actual s3 connection" do
    let(:config) { config = YAML.load_file("s3.yml").map { |k, v| [k.to_sym, v] }.to_h }
    let(:backend) { Refile::S3.new(max_size: 100, **config) }

    it_behaves_like :backend
  end

  context "mocking and stubbing" do
    let(:backend) { Refile::S3.new(region: "us-west-2", bucket: "bucket") }
    let(:s3_resource) { double("s3_resource") }
    let(:s3_client) { double("s3_client") }
    let(:s3_config) { double("s3_config") }
    let(:s3_credentials) { double("s3_credentials") }
    let(:s3_bucket) { double("s3_bucket") }
    let(:s3_object) { double("s3_object") }

    before do
      allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
      allow(s3_resource).to receive(:client).and_return(s3_client)
      allow(s3_client).to receive(:config).and_return(s3_config)
      allow(s3_config).to receive(:credentials).and_return(s3_credentials)
      allow(s3_credentials).to receive(:access_key_id).and_return("access_key_id")
      allow(s3_resource).to receive(:bucket).and_return(s3_bucket)

      allow(backend).to receive(:object).and_return(s3_object)
    end

    it "retries open when Net::OpenTimeout raised" do
      expect(Kernel).to receive(:open).once
      expect(s3_object).to receive(:presigned_url).ordered.and_raise(Net::OpenTimeout)
      expect(s3_object).to receive(:presigned_url).ordered

      backend.open("id")
    end

    it "retries read when Errno::ECONNRESET raised" do
      s3_get = double("get")
      s3_body = double("body")
      allow(s3_get).to receive(:body).and_return(s3_body)
      allow(s3_body).to receive(:read)

      expect(s3_object).to receive(:get).ordered.and_raise(Errno::ECONNRESET)
      expect(s3_object).to receive(:get).ordered.and_return(s3_get)

      backend.read("id")
    end
  end
end

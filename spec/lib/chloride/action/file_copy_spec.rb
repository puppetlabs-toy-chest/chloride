require 'spec_helper'
require 'chloride/action/file_copy'

describe Chloride::Action::FileCopy do
  describe "#go" do
    let(:host) { Chloride::Host.new('somewhere') }

    it "uploads the file via scp" do
      expect(host).to receive(:upload!).with('/from', '/to', an_instance_of(Hash))
      upload = described_class.new(:from => '/from', :to => '/to', :to_host => host)
      upload.go {}
    end

    it "writes to a tempfile if given content" do
      tempfile = double('tempfile').as_null_object
      allow(tempfile).to receive(:path).and_return('/my/tmp/file')
      expect(tempfile).to receive(:write).with('some awesome content')
      expect(Tempfile).to receive(:new).and_return(tempfile)

      expect(host).to receive(:upload!).with('/my/tmp/file', '/to', an_instance_of(Hash))

      upload = described_class.new(:content => 'some awesome content', :to => '/to', :to_host => host)

      upload.go {}
    end

    it "passes through opts to scp" do
      expect(host).to receive(:upload!).with('/from', '/to', include(:verbose => true))
      upload = described_class.new(:from => '/from', :to => '/to', :to_host => host, :opts => {:verbose => true})

      upload.go {}
    end

    it "is successful if the file is uploaded successfully" do
      allow(host).to receive(:upload!)
      upload = described_class.new(:from => '/from', :to => '/to', :to_host => host)

      upload.go {}

      expect(upload).to be_success
    end
    it "is not successful if there is an error" do
      allow(host).to receive(:upload!).and_raise(Net::SCP::Error)
      upload = described_class.new(:from => '/from', :to => '/to', :to_host => host)

      expect { upload.go {} }

      expect(upload).not_to be_success
    end
  end
end

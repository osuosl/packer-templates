driver_version = input('driver_version')
cuda_version = input('cuda_version')

control 'gpu' do
  describe command 'modinfo nvidia' do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /version:\s+#{driver_version}/ }
  end

  describe command 'dkms status' do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /^nvidia.*#{driver_version}.*installed$/ }
  end

  describe command '/usr/local/cuda/bin/nvcc --version' do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /^Cuda compilation tools, release #{cuda_version}/ }
  end

  describe file '/tmp/kitchen/cache/cuda_linux.run' do
    it { should_not exist }
  end

  describe kernel_module 'nouveau' do
    it { should_not be_loaded }
    it { should be_blacklisted }
  end
end

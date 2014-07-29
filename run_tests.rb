require 'net/http'
require 'rubygems'
require 'git'
require 'active_support'

g = Git.open('.')

def http_request_with_timeout_raw(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 20
  request = Net::HTTP::Get.new(uri.request_uri)
  http.request(request)
end

def http_request_with_timeout(uri)
  response =  http_request_with_timeout_raw(uri)
  return false if  response.code == '404' 
  if  response.code == '200' 
    ActiveSupport::JSON.decode(response.body)
  else 
    raise  "Import Failure: Jenkins returned a #{response.code} for #{uri}"
  end
end

def push_commit_to_branch(branch_name)
  `git checkout #{branch_name}`
  `echo #{Time.now.to_s} > README`
  `git add README`
  `git commit -am "blah"`
  `git push origin #{branch_name}`
  `git checkout master`
  exit 1 unless $?.success?
end

def verify_build_success_for_branch(branch_name)
  sha = `git rev-parse origin/#{branch_name}`.strip!
  loop do
    p "Verifying build status for branch #{branch_name}"
    sleep(10)
    url = URI("http://buildmaster2-vm1.snc1:8080/job/release-engineering/job/dotci_test/sha/api/json?value=#{sha}")
    response = http_request_with_timeout(url)  
    if response && !response['building']
      raise "Build for branch #{branch_name} failed #{response['url']}" unless  response['result'] == 'SUCCESS'
      break 
    end
  end 
end

test_branches = g.branches.remote.select {|x| x.name != 'master' && !x.name.start_with?("HEAD")}.map(&:name) 
test_branches.each{ |branch| push_commit_to_branch(branch) ; sleep(10)}
test_branches.each{ |branch| verify_build_success_for_branch(branch)}

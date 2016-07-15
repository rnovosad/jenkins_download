#!/usr/bin/env ruby
# Requirements
require 'net/http'
require 'net/https'
require 'ruby-progressbar'
require 'highline/import'


class JenkinsDownload

  attr_reader :build_number, :code

  def initialize(url, build_url)
    @url = url
    @build_url = build_url
  end

  def connect_to_server
    # Set up connection
    @http = Net::HTTP.new (URI(@url).host)
    @http.use_ssl = URI(@url).scheme == 'https'

    # Ignore certificate issues, for self-issued certs. (Remove this otherwise)
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    # Get the username & password for basic authentication (use Highline)
    @username = ask("Username: ")
    @password = ask("Password: ") {|q| q.echo = false} # Hide the password

    # Create the request and authenticate to get build number
    @request_build_number = Net::HTTP::Get.new(URI(@url))
    @request_build_number.basic_auth(@username, @password)

    @request_build = Net::HTTP::Get.new(URI(@url+@build_url).request_uri)
    @request_build.basic_auth(@username, @password)

    #Parsing html response to receive build number
    @response_build_number = @http.request @request_build_number
    @build_number=@response_build_number.body.match(/nightly \#(\d+)/).to_s.match(/\d+/).to_s
    @code = (@http.request @request_build_number).code.to_i
  end

  def download_build
    begin
      # Open the file for writing
      dest_file = open("/Path/to/file/on/local/drive#{@name}-#{build_number}.extension", "wb")

      # Download the file
      @http.request(@request_build) do |response|
        file_size = response['Content-Length'].to_i
        puts 'File size is: ' + file_size.to_s
        bytes_transferred = 0

        # Initialize the progress bar
        p_bar = ProgressBar.create(:format         => '%a %bᗧ%i %p%% %t',
                                   :progress_mark  => ' ',
                                   :remainder_mark => '･',
                                   :starting_at    => 0,
                                   :total          => file_size)

        # Read the data as it comes in
        response.read_body do |part|
          # Update the total bytes transferred and the progress bar
          bytes_transferred += part.length
          p_bar.progress = bytes_transferred

          # Write the data direct to file
          dest_file.write(part)
        end
        p_bar.finish
      end
    ensure
      dest_file.close
    end
  end
end

name = ask("Build name:")
job = '-part-of-url-with-job-name/'
build_url = '-part-of-url-with-artifact-location'
url = 'http://jenkins.host.com/hudson/view/job/' + name + job + 'lastStableBuild/'
builds = ['array', 'of', 'different', 'builds', 'for download']

#Handling of entering wrong builds
artifact = JenkinsDownload.new(url, build_url)
until builds.include?(name.downcase) do
  p 'Incorrect build name. Please try again.'
  name = ask("Build name:")
end

#Handling of entering wrong credentials
until artifact.connect_to_server == 200
  if artifact.code == 401
    p 'Incorrect username or password. Please try again.'
  #Mock if url is not correct
  elsif artifact.code == 404
    p 'File not found. Please try again.'
  end
end
p 'Build number: ' + artifact.build_number
artifact.download_build

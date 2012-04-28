Sunzi::Dependency.load('fog')

module Sunzi
  module Cloud
    class EC2 < Base
      def initialize(cli)
        super(cli)
        unless File.exist? 'ec2/ec2.yml'
          @cli.empty_directory 'ec2/instances'
          @cli.template 'templates/setup/ec2/ec2.yml', 'ec2/ec2.yml'
          exit_with 'Now go ahead and edit ec2.yml, then run this command again!'
        end

        @config = YAML.load(File.read('ec2/ec2.yml'))

        @ec2 = Fog::Compute.new provider:              'AWS',
                                region:                @config['region'],
                                aws_access_key_id:     @config['access_key_id'],
                                aws_secret_access_key: @config['secret_access_key']

        Fog.credential = @config['credential_name']
      end

      def setup
        print "Launching new server instance at EC2..."

        s = @ec2.servers.bootstrap image_id:   @config['image_id'],
                                  flavor_id:  @config['flavor_id'],
                                  private_key_path: "#{@config['key_path_prefix']}/#{@config['credential_name']}",
                                  public_key_path: "#{@config['key_path_prefix']}/#{@config['credential_name']}.pub",
                                  tags:       { Name: @config['instance_name'] },
                                  username: @config['remote_username']

        puts "", "Started instance '#{s.id}' (#{s.flavor_id}) at #{s.dns_name}", '-'*80
        puts s.tags
      end

      def teardown(target)
        servers = @ec2.servers.select { |s| s.tags["Name"] == @config['instance_name'] && s.state == "running" }

        if servers.size < 1
          puts "No servers running for testing deployment, exiting...", '-'*80
          exit
        end

        puts "Terminating #{servers.size} running servers...", '-'*80
        servers.each do |s|
          puts "* #{s.id} (#{s.flavor.name})"
          s.destroy
        end
      end
    end
  end
end

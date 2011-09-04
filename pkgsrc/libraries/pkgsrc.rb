# Chef package provider for PkgSrc
# Most of this ripped from the homebrew cookbook
# http://community.opscode.com/cookbooks/homebrew

require 'chef/provider/package'
require 'chef/resource/package'
require 'chef/platform'

class Chef
  class Provider
    class Package
      class PkgSrc < Package
        EXTRACT_VERSION = "perl -ne 'print $3 if /(\\S+)(-)(.*?)( +)(.*)/'"

        def load_current_resource
          @current_resource = Chef::Resource::Package.new(@new_resource.name)
          @current_resource.package_name(@new_resource.package_name)
          @current_resource.version(current_installed_version)
          @new_resource.version(candidate_version)

          @current_resource
        end

        def install_package(name, version)
          pkgin('install', name, version)
        end

        def remove_package(name, version)
          pkgin('remove', name, version)
        end

        alias_method :upgrade_package, :install_package
        alias_method :purge_package, :remove_package

        protected
        def pkgin(command, name, version)
          version_string = version.empty? ? nil : "-#{version}"
          run_command_with_systems_locale(
            :command => "pkgin -y #{command} #{name}#{version_string}"
          )
        end

        def current_installed_version
          get_version_from_command("pkgin list | grep #{@new_resource.package_name} | #{EXTRACT_VERSION}")
        end

        def candidate_version
          get_version_from_command("pkgin search #{@new_resource.package_name} | #{EXTRACT_VERSION}")
        end

        def get_version_from_command(command)
          version = get_response_from_command(command).chomp
          version.empty? ? nil : version
        end

        # Nicked from lib/chef/package/provider/macports.rb and tweaked
        # slightly.
        def get_response_from_command(command)
          output = nil
          status = popen4(command) do |pid, stdin, stdout, stderr|
            begin
              output = stdout.read
            rescue Exception => e
              raise Chef::Exceptions::Package, "Could not read from STDOUT on command: #{command}\nException: #{e.inspect}"
            end
          end
          unless (0..1).include? status.exitstatus
            raise Chef::Exceptions::Package, "#{command} failed - #{status.inspect}"
          end
          output
        end
      end
    end
  end
end

Chef::Platform.set :platform => :solaris2, :resource => :package, :provider => Chef::Provider::Package::PkgSrc

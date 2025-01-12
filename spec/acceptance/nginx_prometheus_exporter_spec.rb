# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'prometheus nginx exporter' do
  it 'nginx_prometheus_exporter works idempotently with no errors' do
    shell('puppet module install puppetlabs/apt')
    shell('puppet module install puppet/nginx')
    pp = <<-EOS
  class { 'prometheus::nginx_prometheus_exporter':
    scrape_uri => 'http://localhost:8888/stub_status',
  }
  include nginx
  nginx::resource::server { 'localhost':
    listen_port => 8888,
    locations   => {
      'stub_status' => {
        location    => '/stub_status',
        stub_status => true,
      }
    }
  }
  Class['nginx'] -> Class['prometheus::nginx_prometheus_exporter']
  Nginx::Resource::Server['localhost'] -> Class['prometheus::nginx_prometheus_exporter']
    EOS
    apply_manifest(pp, catch_failures: true)
    apply_manifest(pp, catch_changes: true)
  end

  describe 'default install' do
    describe service('nginx_prometheus_exporter') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe port(9113) do
      it { is_expected.to be_listening.with('tcp6') }
    end

    # the describe process uses `ps -C` which truncates the cmd output to 15 characters on newer versions.
    describe process('nginx-prometheu') do
      its(:args) { is_expected.to match %r{\ -nginx.scrape-uri http://localhost:8888/stub_status} }
    end
  end

  describe 'update to version >= 1.0.0' do
    it 'uses double-dash arguments for version >= 1.0.0' do
      pp = <<-EOS
      class { 'prometheus::nginx_prometheus_exporter':
        scrape_uri => 'http://localhost:8888/stub_status',
        version    => '1.2.0',
      }
      EOS
      apply_manifest(pp, catch_failures: true)
    end

    describe process('nginx-prometheu') do
      its(:args) { is_expected.to match %r{\ --nginx.scrape-uri http://localhost:8888/stub_status} }
    end
  end
end

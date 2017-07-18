#! /usr/bin/env ruby
#
#   check-kube-nodes-minimal-ready.rb
#
# DESCRIPTION:
# => Check if minimal threshold of Kubernetes nodes are in ready to use state
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: kube-client
#
# USAGE:
# -s, --api-server URL             URL to API server
# -v, --api-version VERSION        API version. Defaults to 'v1'
#     --in-cluster                 Use service account authentication
#     --ca-file CA-FILE            CA file to verify API server cert
#     --cert CERT-FILE             Client cert to present
#     --key KEY-FILE               Client key for the client cert
# -u, --user USER                  User with access to API
# -p, --password PASSWORD          If user is passed, also pass a password
# -t, --token TOKEN                Bearer token for authorization
#     --token-file TOKEN-FILE      File containing bearer token for authorization
# -m, --minimal COUNT              Threshold for minimal nodes ready allowed
# -f, --filter FILTER              Selector filter for nodes to be checked
#
# LICENSE:
#   Kel Cecil <kelcecil@praisechaos.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugins-kubernetes/cli'

class MinimalNodesAreReady < Sensu::Plugins::Kubernetes::CLI
  @options = Sensu::Plugins::Kubernetes::CLI.options.dup

  option :minimal_count,
         description: 'Threshold for minimal nodes ready allowed',
         short: '-m COUNT',
         long: '--minimal',
         proc: proc(&:to_i),
         default: 1

  option :node_filter,
         description: 'Selector filter for nodes to be checked',
         short: '-f FILTER',
         long: '--filter'

  def run
    nodes = []
    ready_nodes = []
    minimal_threshold = config[:minimal_count]

    if config[:node_filter].nil?
      nodes = client.get_nodes()
    else
      nodes = client.get_nodes(label_selector: config[:node_filter].to_s)
    end

    nodes.each do |node|
      item = node.status.conditions.detect { |condition| condition.type == 'Ready' }
      if item.nil?
        warning "#{node.name} does not have a status"
      elsif item.status == 'True'
        ready_nodes << node.metadata.name
      else
        warning "#{node.name} status is #{item.status}"
      end
    end

    if ready_nodes.empty?
      critical "No ready nodes found"
    elsif ready_nodes.length < minimal_threshold
      warning "There are less ready nodes (#{ready_nodes.length}) than the minimal threshold (#{minimal_threshold})"
    else
      ok 'All nodes are reporting as ready'
    end

  rescue KubeException => e
    critical 'API error: ' << e.message
  end
end


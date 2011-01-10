begin
  require 'md5'
rescue LoadError
  require 'digest/md5'
end

class Rack::PageSpeed::Filters::CombineJavaScripts < Rack::PageSpeed::Filter
  requires_store
  name      'combine_javascripts'
  priority  2
  
  def execute! document
    nodes = document.css('script[src$=".js"]:not([src^="http"])')
    return false unless nodes.count > 0
    groups = group_siblings topmost_of_sequence(nodes)
    groups.each do |group|
      save group
      merged = merge group, document
      group.first.before merged
      group.map { |node| node.remove }
    end
  end

  private
  def save nodes
    contents = nodes.map { |node| file_for(node).read rescue "" }.join(';')
    nodes_id = unique_id nodes
    @options[:store]["#{nodes_id}.js"] = contents
  end
  
  def merge nodes, document
    nodes_id = unique_id nodes
    node = Nokogiri::XML::Node.new 'script', document
    node['src'] = "/rack-pagespeed-#{nodes_id}.js"
    node
  end
  
  def local_script? node
    node.name == 'script' && !(node['src'] =~ /^http/ or !(node['src'] =~ /.js$/))
  end
  
  def topmost_of_sequence nodes
    result = []
    nodes.each do |node|
      _previous, _next = node.previous_sibling, node.next_sibling
      if _previous && local_script?(_previous) &&
        (!_next || !local_script?(_next))
        result << node
      end
    end
    result
  end

  def unique_id nodes
    Digest::MD5.hexdigest nodes.map { |node| file = file_for node; file.mtime.to_i.to_s + file.read }.join
  end
  
  def group_siblings nodes
    nodes.inject([]) do |result, node|
      group, current = [], node
      group << node
      while previous = current.previous_sibling and local_script?(previous)
        current = previous
        group.unshift current
      end
      result << group
    end
  end
end
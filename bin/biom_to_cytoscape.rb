require "abort_if"
include AbortIf

otus = {}
samples = []
sample_names = []

biom_f = ARGV[0]

inbase = File.basename(biom_f, File.extname(biom_f))
nodes_f = File.join File.dirname(biom_f), "#{inbase}.cytoscape_node_table.txt"
edges_f   = File.join File.dirname(biom_f), "#{inbase}.cytoscape_network_edges.txt"

File.open(nodes_f, "w") do |nf|
  nf.puts %w[otu count].join "\t"

  File.open(biom_f).each_line do |line|
    if line.start_with? "#"
      _, *sample_names = line.chomp.split "\t"
    else
      otu, *counts = line.chomp.split "\t"

      counts = counts.map { |n| n.to_i }

      nf.puts [otu, counts.reduce(:+)].join "\t"

      counts.each_with_index do |count, idx|
        if count > 0
          if samples[idx].nil?
            samples[idx] = [otu]
          else
            samples[idx] << otu
          end
        end
      end
    end
  end
end

warn "LOG -- Nodes: #{nodes_f}"

File.open(edges_f, "w") do |f|
  f.puts %w[node1 node2 sample].join "\t"

  samples.each_with_index do |otus, idx|
    sample_name = sample_names[idx]

    otus.each do |otu|
      f.puts [otu, otu, sample_name].join "\t"
    end

    otus.combination(2).each do |otu1, otu2|
      f.puts [otu1, otu2, sample_name].join "\t"
    end
  end
end

warn "LOG -- Edges: #{edges_f}"

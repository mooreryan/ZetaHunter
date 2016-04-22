samples = {}
sample_names = []

biom_f = ARGV[0]

inbase = File.basename(biom_f, File.extname(biom_f))
nodes_f = File.join File.dirname(biom_f), "#{inbase}.cytoscape_nodes.txt"
edges_f   = File.join File.dirname(biom_f), "#{inbase}.cytoscape_edges.txt"

File.open(nodes_f, "w") do |nf|
  File.open(ARGV.first).each_line do |line|
    if line.start_with? "#"
      _, *sample_names = line.chomp.split "\t"
    else
      otu, *counts = line.chomp.split "\t"

      nf.puts [otu, counts.map{|n| n.to_i}.reduce(:+)].join "\t"

      counts.each_with_index do |count, idx|
        sample_name = sample_names[idx]
        if samples.has_key? sample_name
          samples[sample_name] << otu
        else
          samples[sample_name] = [otu]
        end
      end
    end
  end
end

warn "LOG -- Nodes: #{nodes_f}"

File.open(edges_f, "w") do |f|
  samples.each do |sample, otus|
    otus.combination(2).each do |otu1, otu2|
      f.puts [otu1, otu2].join "\t"
    end
  end
end

warn "LOG -- Edges: #{edges_f}"

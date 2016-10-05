#!/usr/bin/env ruby

# Copyright 2015 - 2016 Ryan Moore
# Contact: moorer@udel.edu
#
# This file is part of ZetaHunter.
#
# ZetaHunter is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ZetaHunter is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ZetaHunter.  If not, see <http://www.gnu.org/licenses/>.

# Last update: 2016-10-05 -- option to exclude small OTUs (mooreryan)

Signal.trap("PIPE", "EXIT")

require "abort_if"
include AbortIf

abort_unless ARGV.count == 1 || ARGV.count == 2,
             "USAGE: biom_to_cytoscape.rb biom_file min_otu_size " +
             "(min_otu_size defaults to 1)"

otus = {}
samples = []
sample_names = []

biom_f = ARGV[0]
min_size = ARGV[1]

if min_size.nil?
  min_size = 1
else
  min_size = min_size.to_i
end

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

      total = counts.reduce(:+)

      unless otu.start_with?("NewZetaOtu") && total < min_size
        nf.puts [otu, total].join "\t"

        counts.each_with_index do |count, idx|
          if count > 0 # it exists in this sample
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
end

warn "LOG -- Nodes: #{nodes_f}"

File.open(edges_f, "w") do |f|
  f.puts %w[node1 node2 sample].join "\t"

  samples.each_with_index do |otus, idx|
    # if a sample has 0 count for all OTUs the otus ary will be
    # nil
    unless otus.nil?
      sample_name = sample_names[idx]

      if otus.count == 1 # put the self connection so that it shows up
        otu = otus[0]
        f.puts [otu, otu, sample_name].join "\t"
      end

      otus.combination(2).each do |otu1, otu2|
        f.puts [otu1, otu2, sample_name].join "\t"
      end
    end
  end
end


warn "LOG -- Edges: #{edges_f}"

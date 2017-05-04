#!/usr/bin/env ruby

require "pp"
require "abort_if"

include AbortIf
include AbortIf::Assert

Signal.trap("PIPE", "EXIT")

db_info_f = ARGV[0]
dist_f    = ARGV[1]

otus = {}
File.open(db_info_f).each_line do |line|
  unless line.start_with? "#"
    acc, otu, *rest = line.chomp.split "\t"

    if otus.has_key? otu
      otus[otu] << acc
    else
      otus[otu] = [acc]
    end
  end
end

dists = {}
seqs = []
num_seqs = -1
File.open(dist_f).each_line.with_index do |line, idx|
  if idx.zero?
    num_seqs = line.chomp.to_i
  else
    seq, *all_dists = line.chomp.split "\t"
    seq.strip!
    all_dists.map!(&:to_f)

    seqs << seq

    if all_dists.empty?
      dists[seq] = { seq => 0.0 }
    else
      all_dists.each_with_index do |dist, dist_i|

        if dist_i.zero?
          dists[seq] = { seq => 0.0 }
        end

        other_seq = seqs[dist_i]
        dists[seq][other_seq] = dist
        dists[other_seq][seq] = dist
      end
    end
  end
end

assert dists.count == num_seqs
assert dists.values.map(&:count).all? { |count| count == num_seqs
}

otus.each do |otu, seqs|
  if seqs.count == 1
    mean_sim = 97
    max_sim = 97
  else
    in_otu_dists = []
    seqs.combination(2).each do |s1, s2|
      dist = dists[s1][s2]

      in_otu_dists << dist
    end

    mean_sim =
      (100 - (in_otu_dists.reduce(:+) / in_otu_dists.count * 100)).round

    max_sim =
      (100 - (in_otu_dists.max * 100)).round

  end

  p [otu,
     seqs.count,
     mean_sim,
     max_sim]
end

require "parse_fasta"

seqs = []
FastaFile.open(ARGV.first, "rt").each_record do |head, seq|
  seqs << seq.chars
end

seqs.first.zip(seqs.last).each do |c1, c2|
  p [c1, c2] if c1 != "-" || c2 != "-"
end

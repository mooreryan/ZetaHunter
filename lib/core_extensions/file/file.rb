# Copyright 2016 - 2018 Ryan Moore
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

module CoreExtensions
  module File
    Filename = Struct.new :dir, :base, :ext

    def parse_fname fname
      Filename.new Object::File.dirname(fname),
                   Object::File.basename(fname,
                                         Object::File.extname(fname)),
                   Object::File.extname(fname)
    end

    def clean_fname str
      str.split(Object::File::SEPARATOR).
        map { |s| s.gsub(/[^\p{Alnum}\.]+/, "_") }.
        join(Object::File::SEPARATOR)
    end

    def clean_and_copy fname
      new_fname = clean_fname fname
      new_dirname = Object::File.dirname new_fname

      unless new_fname == fname

        FileUtils.mkdir_p new_dirname
        FileUtils.cp fname, new_fname

        # logger.info { "Copying #{fname} to #{new_fname}" }

        # assert_file new_fname
      end

      new_fname
    end

    def read_entropy fname
      entropy = []
      Object::File.open(fname, "rt").each_line do |line|
        idx, ent = line.chomp.split "\t"
        # assert !idx.nil? && !idx.empty?
        # assert !ent.nil? && !ent.empty?

        entropy[idx.to_i] = ent.to_f
      end

      # assert entropy.count == MASK_LEN,
      #        "Entropy count was %d should be %d",
      #        entropy.count,
      #        MASK_LEN

      entropy
    end

    def to_set fname
      lines = []
      Object::File.open(fname, "rt").each_line do |line|
        lines << line.chomp
      end

      Set.new lines
    end
  end
end

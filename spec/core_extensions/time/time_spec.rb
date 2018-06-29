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

require "spec_helper"
require "logger"

describe CoreExtensions::Time do
  Time.extend CoreExtensions::Time

  let(:logger) { Logger.new STDERR }
  let(:title) { "Hello, World!" }

  describe "#date_and_time" do
    context "with default agruments" do
      it "pretty prints date and time" do
        rgx = %r{
          [0-9]{4} # year
          -
          [01][0-9] # month
          -
          [0-3][0-9] # day
          \s
          [0-2][0-9] # hours
          :
          [0-5][0-9] # minutes
          :
          [0-5][0-9] # seconds
          \.
          [0-9]{3} # decimal seconds
        }x

        expect(Time.date_and_time).to match rgx
      end
    end
  end

  describe "#time_it" do
    context "when run is true" do
      it "yields the block" do
        expect { |b| Time.time_it title, &b }.to yield_control
      end

      context "with no logger" do
        context "with no title" do
          it "prints default message to stderr" do
            out = /\AFinished in .* seconds\n\z/

            expect { Time.time_it {} }.to output(out).to_stderr
          end
        end

        context "with title" do
          it "prints with specific msg to stderr" do
            out = /\A#{title} finished in .* seconds\n\z/

            expect { Time.time_it(title) {} }.to output(out).to_stderr
          end
        end
      end

      context "with logger" do
        context "with no title" do
          it "prints default info logger message"
        end

        context "with title" do
          it "prints with specific logger msg"
        end
      end
    end

    context "when run is false" do
      it "doesn't yield the block" do
        expect { |b| Time.time_it title, run: false, &b }.
          not_to yield_control
      end

      it "doesn't print anything" do
        expect { |b| Time.time_it(title, run: false) {} }.
          not_to output.to_stderr
      end
    end
  end
end

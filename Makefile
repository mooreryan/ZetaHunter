TEST_OUT_D = TEST_OUTDIR
TEST_FILE_D = ./spec/test_files/run_zeta_hunter/snazzy_test

TEST_D1 = $(TEST_FILE_D)/"dir with spaces"
TEST_D2 = $(TEST_FILE_D)/dir_without_spaces

EXPECTED_OTU_CALLS = $(TEST_FILE_D)/../snazzy_test_final_otu_calls.txt
ACTUAL_OTU_CALLS = otu_calls/test.otu_calls.final.txt

ifeq ($(THREADS),)
THREADS = 2
endif


.PHONY: test_all
.PHONY: test_ruby
.PHONY: test_docker
.PHONY: test_rspec
.PHONY: pull_docker_image

test_all: test_ruby test_docker test_rspec

test_ruby:
	rm -r $(TEST_OUT_D).ruby; time ruby zeta_hunter.rb -i $(TEST_D1)/* $(TEST_D2)/* -o $(TEST_OUT_D).ruby -t $(THREADS) -a test && diff $(TEST_OUT_D).ruby/$(ACTUAL_OTU_CALLS) $(EXPECTED_OTU_CALLS)

test_docker: pull_docker_image
	rm -r $(TEST_OUT_D).docker; time bin/run_zeta_hunter -i $(TEST_D1)/* $(TEST_D2)/* -o $(TEST_OUT_D).docker -t $(THREADS) -a test && diff $(TEST_OUT_D).docker/$(ACTUAL_OTU_CALLS) $(EXPECTED_OTU_CALLS)

test_rspec:
	bundle exec rspec

# test_rspec_docker: pull_docker_image
# 	docker run --workdir /home/ZetaHunter mooreryan/zetahunter bundle exec rspec

pull_docker_image:
	docker pull mooreryan/zetahunter

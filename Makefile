TEST_OUT_D = TEST_OUTDIR
TEST_FILE_D = ./spec/test_files/run_zeta_hunter/snazzy_test

TEST_D1 = $(TEST_FILE_D)/"dir with spaces"
TEST_D2 = $(TEST_FILE_D)/dir_without_spaces

EXPECTED_OTU_CALLS = $(TEST_FILE_D)/../snazzy_test_final_otu_calls.txt
ACTUAL_OTU_CALLS = $(TEST_OUT_D)/otu_calls/test.otu_calls.final.txt

ifeq ($(THREADS),)
THREADS = 2
endif


.PHONY: test_all
.PHONY: test_ruby
.PHONY: test_docker
.PHONY: test_rspec
.PHONY: rm_test_outdir
.PHONY: pull_docker_image

test_all: test_ruby test_docker test_rspec test_rspec_docker

test_ruby: rm_test_outdir
	time ruby zeta_hunter.rb -i $(TEST_D1)/* $(TEST_D2)/* -o $(TEST_OUT_D) -t $(THREADS) -a test && diff $(ACTUAL_OTU_CALLS) $(EXPECTED_OTU_CALLS)

test_docker: rm_test_outdir pull_docker_image
	time bin/run_zeta_hunter -i $(TEST_D1)/* $(TEST_D2)/* -o $(TEST_OUT_D) -t $(THREADS) -a test && diff $(ACTUAL_OTU_CALLS) $(EXPECTED_OTU_CALLS)

test_rspec: rm_test_outdir
	bundle exec rspec

test_rspec_docker: rm_test_outdir pull_docker_image
	docker run --workdir /home/ZetaHunter mooreryan/zetahunter bundle exec rspec

rm_test_outdir:
	[ ! -e $(TEST_OUT_D) ] || rm -r $(TEST_OUT_D)

pull_docker_image:
	docker pull mooreryan/zetahunter

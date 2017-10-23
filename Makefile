TEST_OUT_D = TEST_OUTDIR
TEST_FILE_D = test_files
DIR_WITH_SPACES = $(TEST_FILE_D)/"dir with spaces"
TEST_FILES = $(TEST_FILE_D)/"kitties say meow.fa" \
             $(TEST_FILE_D)/"not a zeta.fa.gz" \
             $(TEST_FILE_D)/"seqs.fa.gz" \
             $(TEST_FILE_D)/"silly.fa" \
             $(DIR_WITH_SPACES)/"apple.fa.gz" \
             $(DIR_WITH_SPACES)/"fruit snacks.fa" \
             $(DIR_WITH_SPACES)/"ginger_ale.fa" \
             $(DIR_WITH_SPACES)/"pie is good.fa.gz" \

SNAZZY_D = $(TEST_FILE_D)/snazzy_test

.PHONY: test
.PHONY: test_docker
.PHONY: test_snazzy
.PHONY: profile_snazzy

test:
	rm -r $(TEST_OUT_D); time ruby zeta_hunter.rb -i $(TEST_FILES) -o $(TEST_OUT_D) -t 4

test_docker:
	rm -r $(TEST_OUT_D); time bin/run_zeta_hunter -i $(SNAZZY_D)/*/* -o $(TEST_OUT_D) -t 4 -a test

test_snazzy:
	rm -r $(TEST_OUT_D); time ruby zeta_hunter.rb -i $(SNAZZY_D)/*/* -o $(TEST_OUT_D) -t 4 -a test

profile_snazzy:
	rm -r $(TEST_OUT_D); time ruby-prof -p call_stack -f snazzy_profile.html zeta_hunter.rb -- -i $(SNAZZY_D)/*/* -o $(TEST_OUT_D) -t 4 -a test && diff $(TEST_OUT_D)/otu_calls/test.otu_calls.final.txt $(TEST_FILE_D)/snazzy_final_otu_calls.txt

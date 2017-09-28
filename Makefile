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

SPIFFY_D = $(TEST_FILE_D)/spiffy_test

.PHONY: test
.PHONY: test_docker
.PHONY: test_fast
.PHONY: test_spiffy

test:
	rm -r $(TEST_OUT_D); time ruby zeta_hunter.rb -i $(TEST_FILES)-o $(TEST_OUT_D) -t 4

test_docker:
	rm -r $(TEST_OUT_D); time bin/run_zeta_hunter -i $(TEST_FILES) -o $(TEST_OUT_D) -t 4

test_fast:
	rm -r $(TEST_OUT_D); time ruby zeta_hunter.rb -i $(TEST_FILES) -o $(TEST_OUT_D) -t 4 --no-check-chimeras

test_spiffy:
	rm -r $(TEST_OUT_D); time ruby zeta_hunter.rb -i $(SPIFFY_D)/*/* -o $(TEST_OUT_D) -t 4

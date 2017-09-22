TEST_OUT_D = TEST_OUTDIR

.PHONY: test
.PHONY: test_fast

test:
	rm -r $(TEST_OUT_D); time ruby zeta_hunter.rb -i test_files/*.fa.gz "test_files/dir with spaces"/two.fa -o $(TEST_OUT_D) -t 4

test_docker:
	rm -r $(TEST_OUT_D); time bin/run_zeta_hunter -i test_files/*.fa.gz "test_files/dir with spaces"/two.fa -o $(TEST_OUT_D) -t 4

test_fast:
	rm -r $(TEST_OUT_D); time ruby zeta_hunter.rb -i test_files/*.fa.gz -o $(TEST_OUT_D) -t 4 --no-check-chimeras

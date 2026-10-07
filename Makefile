.PHONY: bootstrap check smoke regression coverage vcs-smoke vcs-regression verdi clean

bootstrap:
	bash scripts/bootstrap_oss.sh

check:
	python3 scripts/check_project.py

smoke: bootstrap check
	bash -lc 'source .env.oss && FORCE_REBUILD=1 TEST=dma_smoke_test SEED=1 bash scripts/run_verilator.sh'

regression: bootstrap check
	bash -lc 'source .env.oss && bash scripts/oss_regression.sh'

coverage:
	bash scripts/merge_coverage.sh
	python3 scripts/summarize_regression.py

vcs-smoke:
	bash scripts/setup_dut.sh
	FORCE_REBUILD=1 TEST=dma_smoke_test SEED=1 bash scripts/run_vcs.sh

vcs-regression:
	bash scripts/setup_dut.sh
	bash scripts/vcs_regression.sh

verdi:
	bash scripts/open_verdi.sh

clean:
	rm -rf out .env.oss

-include .env
.PHONY: install deploy-contracts test coverage coverage-html

install:
	forge install

deploy-contracts:
	forge script script/Deploy.s.sol \
		--rpc-url ${ETH_RPC_URL} --sender ${DEPLOY_ADDRESS} --keystore ${DEPLOY_KEY} --broadcast -vvv
	 
test:
	forge test

coverage:
	forge coverage

coverage-html:
	forge coverage --report lcov
	genhtml lcov.info --branch-coverage --output-dir coverage

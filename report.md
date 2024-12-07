# **Euro Dollar Audit Competition on Hats.finance** 


## Introduction to Hats.finance


Hats.finance builds autonomous security infrastructure for integration with major DeFi protocols to secure users' assets. 
It aims to be the decentralized choice for Web3 security, offering proactive security mechanisms like decentralized audit competitions and bug bounties. 
The protocol facilitates audit competitions to quickly secure smart contracts by having auditors compete, thereby reducing auditing costs and accelerating submissions. 
This aligns with their mission of fostering a robust, secure, and scalable Web3 ecosystem through decentralized security solutions​.

## About Hats Audit Competition


Hats Audit Competitions offer a unique and decentralized approach to enhancing the security of web3 projects. Leveraging the large collective expertise of hundreds of skilled auditors, these competitions foster a proactive bug hunting environment to fortify projects before their launch. Unlike traditional security assessments, Hats Audit Competitions operate on a time-based and results-driven model, ensuring that only successful auditors are rewarded for their contributions. This pay-for-results ethos not only allocates budgets more efficiently by paying exclusively for identified vulnerabilities but also retains funds if no issues are discovered. With a streamlined evaluation process, Hats prioritizes quality over quantity by rewarding the first submitter of a vulnerability, thus eliminating duplicate efforts and attracting top talent in web3 auditing. The process embodies Hats Finance's commitment to reducing fees, maintaining project control, and promoting high-quality security assessments, setting a new standard for decentralized security in the web3 space​​.

## Euro Dollar Overview

Eurodollar.fi offers a compliant_ European stablecoin with options for secure transactions and yield generation.

## Competition Details


- Type: A public audit competition hosted by Euro Dollar
- Duration: 2 weeks
- Maximum Reward: $15,015
- Submissions: 131
- Total Payout: $10,885.87 distributed among 6 participants.

## Scope of Audit

4 contracts up for review which relates to new tokens, a stablecoin and various "Invest Tokens" which are backed by RWA with price controls through the YieldOracle.

~ 400 lines of code, mostly OpenZeppelin modules and other industry standards.

USDE.sol
InvestToken.sol
Validator.sol
YieldOracle.sol
USDE.sol
Dollar based stablecoin with syngergetic capabilities with InvestToken.sol

InvestToken.sol
Reusable contract for spawning new digital assets backed and supported by Eurodollar

Validator.sol
Compliance and regulatory contract with the ability to blacklist and allowlist users to Eurodollar provided assets.

YieldOracle.sol
Onchain key value store of the exchange rate between USDE.sol and InvestToken.sol.

.
├── foundry.toml
├── interfaces
│   ├── IUSDE.sol
│   ├── IEUI.sol
│   └── IYieldOracle.sol
├── script
│   └── Deploy.s.sol
├── src
│   ├── USDE.sol
│   ├── interfaces
│   │   ├── IUSDE.sol
│   │   ├── IValidator.sol
│   │   └── IYieldOracle.sol
│   ├── InvestToken.sol
│   ├── Validator.sol
│   └── YieldOracle.sol
└── test
    ├── Constants.sol
    ├── USDE.t.sol
    ├── InvestToken.sol
    ├── Validator.t.sol
    └── YieldOracle.t.sol


**Areas of security research interest:**
* Price manipulation attacks.
* Loss of funds
* Contract(s) Denial-of-Service.
* White/blacklist bypass.
Flipping attack vectors.
[...]

## High severity issues


- **InvestToken Exploitable Due to Price Discrepancy in Mint and Withdraw Functions**

  `InvestToken`, designed to mimic an ERC4626 vault, is experiencing a critical flaw that allows potential exploitation through arbitrage. This token uses the `YieldOracle` to determine exchange rates for USDE, its underlying asset. There is an inconsistency in how exchange rates are applied for different actions. The `mint` and `redeem` functions utilize the previous price via `convertToAsset()`, while `deposit` and `withdraw` use the current price through `assetsToShares()`. This discrepancy creates an opportunity for arbitrage by exploiting the price difference. A whitelisted investor can convert USDE to shares at a lower price using `mint` and then immediately withdraw the shares at a higher price using `withdraw`, earning a profit from the price differential. This process can be repeated to inflate USDE to an infinite amount, posing a risk of market manipulation and potential protocol insolvency. The recommendation is to align the price use for minting and depositing actions with the current price, and redeeming and withdrawing actions with the previous price, in adherence to ERC4626 vault patterns. This flaw was identified and demonstrated through a proof-of-concept file, which assists in understanding and addressing the issue.


  **Link**: [Issue #45](https://github.com/hats-finance/Euro-Dollar-0xa4ccd3b6daa763f729ad59eae75f9cbff7baf2cd/issues/45)

## Medium severity issues


- **Blacklisted Users Can Bypass Restrictions and Gain Yield Using InvestToken Deposit Function**

  A vulnerability exists in the system where a blacklisted account can bypass its restrictions by transferring USDE to an invest coin and redeeming it through a different, unblacklisted account. This loophole allows the blacklisted user to unlock and utilize USDE, invest in coins, and generate yield, effectively undermining the blacklist's purpose. The core issue lies in the `InvestToken.deposit` function, which burns USDE from the blacklisted user's account without verifying the blacklist status. As a result, blacklisted users can deposit their USDE, receive shares in a whitelisted account, and circumvent blacklist restrictions. To mitigate this issue, the system needs to check if `msg.sender` is blacklisted in the `InvestToken.deposit` function to prevent unauthorized transactions.


  **Link**: [Issue #58](https://github.com/hats-finance/Euro-Dollar-0xa4ccd3b6daa763f729ad59eae75f9cbff7baf2cd/issues/58)

## Low severity issues


- **Malicious BLACKLISTER_ROLE Can Temporarily Disrupt USDE Burn and Deposit Functions**

  A potential issue allows a malicious BLACKLISTER_ROLE to temporarily disrupt the USDE token's burning mechanism by blacklisting `address(0)`, causing the burn to fail. This vulnerability stems from the logic in the `isValid()` function, impacting deposits and burns for all users until corrected. Prohibiting blacklisting `address(0)` is suggested as a preventive measure.


  **Link**: [Issue #84](https://github.com/hats-finance/Euro-Dollar-0xa4ccd3b6daa763f729ad59eae75f9cbff7baf2cd/issues/84)


- **Improve maxMint and maxDeposit functions by checking USDE contract pause status**

  In `InvestToken.sol`, the functions `maxMint()` and `maxDeposit()` currently return zero when the contract is paused, indicating that no deposits or mints can occur. To improve accuracy, these functions could also check if the `USDE` contract is paused. This would ensure comprehensive status checking before proceeding with mints or deposits.


  **Link**: [Issue #47](https://github.com/hats-finance/Euro-Dollar-0xa4ccd3b6daa763f729ad59eae75f9cbff7baf2cd/issues/47)


- **Issue with Inconsistent Outcomes Using Withdraw and Redeem in InvestToken Contract**

  The `InvestToken` contract has issues with withdrawal and deposit functionalities due to two functions, `withdraw` and `redeem`, that use different price calculations from the `YieldOracle`. This discrepancy can lead to different outcomes for users withdrawing the same assets under the same conditions, causing potential vulnerabilities and inconsistencies in the rewards system.


  **Link**: [Issue #41](https://github.com/hats-finance/Euro-Dollar-0xa4ccd3b6daa763f729ad59eae75f9cbff7baf2cd/issues/41)


- **Vulnerability in InvestToken Contract's Price Calculation Mechanism During Withdrawals**

  A vulnerability in the InvestToken contract causes inconsistent price references during asset conversion, leading to user losses in emergency withdrawals. The currentPrice is used for deposits while the previousPrice is used for withdrawals, creating discrepancies. Delays or malfunctions in Oracle price updates can exacerbate this issue, affecting the contractual balance.


  **Link**: [Issue #34](https://github.com/hats-finance/Euro-Dollar-0xa4ccd3b6daa763f729ad59eae75f9cbff7baf2cd/issues/34)



## Conclusion

The Euro Dollar audit competition hosted by Hats.finance highlights several critical smart contract vulnerabilities, offering valuable insights into decentralized security's role in strengthening DeFi projects. The competition involved auditing four contracts associated with Eurodollar.fi's stablecoin and its associated tokens, focusing on issues like price manipulation and access control weaknesses. A notable high-severity flaw was found in the InvestToken, where exploitable discrepancies in price calculations—between mint and withdraw—could allow for infinite inflation and potential market manipulation. Medium-severity issues included vulnerabilities that allowed blacklisted users to bypass restrictions and exploit contract functionalities to gain yield. Moreover, several low-severity concerns were pointed out, suggesting improvements to enhance code resilience against potential disruptions. Hats.finance's pay-for-results methodology ensures efficient budget allocation while enhancing security, as evidenced by the $10,885.87 distributed among successful auditors. This audit underscores the importance of proactive security measures in DeFi, setting an innovative standard for decentralized security engagements in the web3 landscape.

## Disclaimer


This report does not assert that the audited contracts are completely secure. Continuous review and comprehensive testing are advised before deploying critical smart contracts.


The Euro Dollar audit competition illustrates the collaborative effort in identifying and rectifying potential vulnerabilities, enhancing the overall security and functionality of the platform.


Hats.finance does not provide any guarantee or warranty regarding the security of this project. Smart contract software should be used at the sole risk and responsibility of users.


# Solidity Style Guide

## Basic

- Contracts, libraries etc. should be camel-case with first letter capitalized i.e. `PriceController`
- Camel-case with initial lowercase letters for variables and functions i.e. `setPrice(uint256 newPrice)`
- Constants: should be in all caps and snake_case i.e. `PRICE_PRECISION`
- Prefix parameters with an underscore `_` if passing in constructor i.e. if you want to pass in a `_startPrice` and set `startPrice = _startPrice`
- Prefix internal functions with an underscore i.e. `_priceHelper()`
- Always use uint256 over uint
- Always explicitly return values (i.e. do not give return vars names) i.e. `function getNewPrice() public view returns (uint256)`
- Always do comments with /// except for within a function use //
- Try to fill out natspec with to the best of ability
  - Official doc: https://docs.soliditylang.org/en/develop/natspec-format.html
  - Do not use `section headers`; ex. `/* ========== PUBLIC FUNCTIONS ========== */`
- Events should be defined in the interface if applicable otherwise in the contract
  - Default rule to index ID-Related values && addresses, not integers i.e. `address indexed sender`
- Error messages: descriptive but short (under ~30-40 chars ideally) with format: `contractName(): error message`
  - Future: reformatting of codebase with error codes for gas efficiencies if deemed appropriate.
- Always do exponential numbers as `100 * 10 ** 18`, not `100 * 10e18`
- Always explicitly set names for numbers in functions, rather than passing in `150000` and expecting people to know the context of this number.
- Dependencies: always add submodules using `forge install <githubRepoName>`
  - ex. `forge install OpenZeppelin/openzeppelin-contracts`
  - Add submodule to `foundry.toml` in `remappings` and modify to have ‘@’ symbol for beginning of `import`
    - ex. `remappings = ["@openzeppelin=lib/openzeppelin-contracts/"]`
  - Add new `remapping` to `settings.json` to avoid error lines in code editor

## Testing

- All tests in solidity with Foundry
- Use `testCannot` over `testRevert`
- Comment above test describing it / or any relevant details
- Local mainnet fork testing:
  - `Setup.t.sol` to be used as inherited abstract contract for universal setup vars and environment
  - `setup()` within local test file, ex. `dutchAuction.t.sol` to be used for custom setup features required for specific contract testing
  - Apply approves and ERC20 transfers in `setup()` or `Setup.t.sol` if repetitive through tests

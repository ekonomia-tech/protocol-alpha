# Solidity Style Guide
## Basic
- Always use uint256 over uint
- Always explicitly return values (i.e. do not give return vars names)
- Always do comments with ///
- Always fill out natspec with......
- Something about forge remappings.....
- Events should be mentioned in both the file and the interface? (Or just the interface? What is better?)
- Always keep require messages under X length
- Error keyword? When to use, if ever?
- Always do exponential numbers as 100 * 10 ** 18, not 100 * 10e18
- Always explicitly set names for numbers in functions, rather than passing in `150000` and expecting people to know the context of this number.
- Camel-case for variables and functions
- Prefix parameters with an `_` (.... i could also go without this)
- ....CONTINUE

## Testing
- All tests in solidity with Foundry
- Use `testCannot` over `testRevert`
- Mention stuff about constants, setups, mainnet forks, etc.... 
# Known Issues
In the contract StableCoin.sol, the function `mint` can be called by any address, not just the owner.
This allows any address to mint tokens to any other address, which is a critical issue.
```solidity
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
```


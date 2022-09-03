
Emissions for TON will mirror CRV's liquidity gauges: https://curve.readthedocs.io/dao-gauges.html

CRV contracts:
- `LiquidityGauge`: what users deposit lp tokens into to earn rewards [code](https://github.com/curvefi/curve-dao-contracts/blob/master/contracts/gauges/LiquidityGaugeV5.vy)
- `GaugeController`: holds a list of gauges info, controls rate of CRV production for each gauge
- `Minter`: mints CRV

For CRV emissions, only people that deposit LP tokens into the `LiquidityGauge` get CRV rewards. Will we be doing something similar for stableoin (PHO) minters?

what does the deposit function into `LiquidityGauge` look like?

[code](https://github.com/curvefi/curve-dao-contracts/blob/3bee979b7b6293c9e7654ee7dfbf5cc9ff40ca58/contracts/gauges/LiquidityGauge.vy#L279)

```python
# deposit function

self._checkpoint(addr)

# value is the amt locked
if _value != 0:
    _balance: uint256 = self.balanceOf[addr] + _value
    _supply: uint256 = self.totalSupply + _value

    # update balance for user who deposited
    self.balanceOf[addr] = _balance
    # update supply within the liquidity gauge for everyone
    self.totalSupply = _supply

    self._update_liquidity_limit(addr, _balance, _supply)

    assert ERC20(self.lp_token).transferFrom(msg.sender, self, _value)
```

what is the `_update_liquidity_limit`?

[code](https://github.com/curvefi/curve-dao-contracts/blob/3bee979b7b6293c9e7654ee7dfbf5cc9ff40ca58/contracts/gauges/LiquidityGauge.vy#L125)

seems to be related to veBoost, might not be super important right now

TODO: dig into this further later when we use the veBoost and VoteEscrow setup

what is the `_checkpoint` function?

used by both deposit and withdraw functions

```python
def _checkpoint(addr: address):
    """
    @notice Checkpoint for a user
    @param addr User address
    """
    _token: address = self.crv_token
    _controller: address = self.controller
    # TODO: ?
    _period: int128 = self.period
    # TODO: ?
    _period_time: uint256 = self.period_timestamp[_period]
    # TODO: what is this used for?
    # definition in the docs
    _integrate_inv_supply: uint256 = self.integrate_inv_supply[_period]
    # TODO: does this change?
    rate: uint256 = self.inflation_rate
    # TODO: whats the new rate for?
    new_rate: uint256 = rate
    # TODO: what is this future_epoch_time for?
    prev_future_epoch: uint256 = self.future_epoch_time
    # TODO: what 
    if prev_future_epoch >= _period_time:
        self.future_epoch_time = CRV20(_token).future_epoch_time_write()
        new_rate = CRV20(_token).rate()
        self.inflation_rate = new_rate

    # TODO: dig into what this does and how it modifies the guage controller
    # calls this https://github.com/curvefi/curve-dao-contracts/blob/3bee979b7b6293c9e7654ee7dfbf5cc9ff40ca58/contracts/GaugeController.vy#L336
    Controller(_controller).checkpoint_gauge(self)

    # TODO: what are these for?
    _working_balance: uint256 = self.working_balances[addr]
    _working_supply: uint256 = self.working_supply

    if self.is_killed:
        rate = 0  # Stop distributing inflation as soon as killed

    # Update integral of 1/supply
    # TODO: it updates integrate_inv_supply by why is that important?
    # TODO: what is _period_time?
    if block.timestamp > _period_time:
        prev_week_time: uint256 = _period_time
        week_time: uint256 = min((_period_time + WEEK) / WEEK * WEEK, block.timestamp)

        for i in range(500):
            dt: uint256 = week_time - prev_week_time
            w: uint256 = Controller(_controller).gauge_relative_weight(self, prev_week_time / WEEK * WEEK)

            if _working_supply > 0:
                if prev_future_epoch >= prev_week_time and prev_future_epoch < week_time:
                    # If we went across one or multiple epochs, apply the rate
                    # of the first epoch until it ends, and then the rate of
                    # the last epoch.
                    # If more than one epoch is crossed - the gauge gets less,
                    # but that'd meen it wasn't called for more than 1 year
                    _integrate_inv_supply += rate * w * (prev_future_epoch - prev_week_time) / _working_supply
                    rate = new_rate
                    _integrate_inv_supply += rate * w * (week_time - prev_future_epoch) / _working_supply
                else:
                    _integrate_inv_supply += rate * w * dt / _working_supply
                # On precisions of the calculation
                # rate ~= 10e18
                # last_weight > 0.01 * 1e18 = 1e16 (if pool weight is 1%)
                # _working_supply ~= TVL * 1e18 ~= 1e26 ($100M for example)
                # The largest loss is at dt = 1
                # Loss is 1e-9 - acceptable

            if week_time == block.timestamp:
                break
            prev_week_time = week_time
            week_time = min(week_time + WEEK, block.timestamp)

    _period += 1
    self.period = _period
    self.period_timestamp[_period] = block.timestamp
    self.integrate_inv_supply[_period] = _integrate_inv_supply

    # Update user-specific integrals
    self.integrate_fraction[addr] += _working_balance * (_integrate_inv_supply - self.integrate_inv_supply_of[addr]) / 10 ** 18
    self.integrate_inv_supply_of[addr] = _integrate_inv_supply
    self.integrate_checkpoint_of[addr] = block.timestamp

```

what does 